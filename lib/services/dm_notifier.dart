import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import 'direct_message_service.dart';
import 'profile_service.dart';
import 'sfx_service.dart';

/// A private message that just arrived, with who sent it.
class DmAlert {
  const DmAlert({required this.from, required this.message});

  final Profile from;
  final DirectMessage message;
}

/// Watches for private messages anywhere in the app (while signed in):
/// counts unread ones per friend (remembered on this device, so messages
/// that came while the app was closed count too), plays a sound and raises
/// an alert for the banner - unless that conversation is already open.
class DmNotifier {
  DmNotifier._();

  /// Unread messages per friend id.
  static final ValueNotifier<Map<String, int>> unread = ValueNotifier(const {});

  /// All unread messages.
  static int get totalUnread => unread.value.values.fold(0, (a, b) => a + b);

  /// The newest message that should be shown in a banner.
  static final ValueNotifier<DmAlert?> alert = ValueNotifier(null);

  /// The friend whose conversation is open on screen (no alerts for them).
  static String? _openWith;

  /// Opens the conversation with a friend (set by whichever screen can:
  /// the tavern shows it in its side panel; elsewhere it's a full screen).
  /// The latest registered opener wins; screens remove theirs on close.
  static final List<void Function(Profile friend)> _openers = [];

  static void addOpener(void Function(Profile friend) open) =>
      _openers.add(open);

  static void removeOpener(void Function(Profile friend) open) =>
      _openers.remove(open);

  /// Opens the conversation with [friend] the way the current screen does.
  static void open(Profile friend) {
    if (_openers.isNotEmpty) _openers.last(friend);
  }

  static DirectMessageFeed? _feed;
  static StreamSubscription<AuthState>? _auth;
  static final Map<String, Profile> _profiles = {};

  /// When each conversation was last seen (ISO time, per friend id), and
  /// when this device started counting (nothing older counts as unread).
  static const String _seenKey = 'dm_seen';
  static const String _sinceKey = 'dm_since';
  static Map<String, DateTime> _seen = {};
  static DateTime _since = DateTime.now();

  /// Starts watching (and restarts on sign-in / sign-out). Call once.
  static void start() {
    _auth ??= Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      switch (state.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.initialSession:
          if (state.session != null) _connect();
        case AuthChangeEvent.signedOut:
          _disconnect();
        default:
          break;
      }
    });
    if (Supabase.instance.client.auth.currentUser != null) _connect();
  }

  static Future<void> _connect() async {
    if (_feed != null) return;
    await _loadSeen();
    _feed = DirectMessageService.listen(
      onNew: _onNew,
      onEdited: (_) {},
      onDeleted: (_) {},
    );
    await _countMissed();
  }

  static Future<void> _disconnect() async {
    await _feed?.close();
    _feed = null;
    unread.value = const {};
    alert.value = null;
    _profiles.clear();
  }

  static Future<void> _loadSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final since = prefs.getString(_sinceKey);
      if (since == null) {
        // First run on this device: start counting from now.
        _since = DateTime.now();
        await prefs.setString(_sinceKey, _since.toUtc().toIso8601String());
      } else {
        _since = DateTime.parse(since).toLocal();
      }
      final raw = prefs.getString(_seenKey);
      _seen = raw == null
          ? {}
          : {
              for (final e in (jsonDecode(raw) as Map).entries)
                e.key as String: DateTime.parse(e.value as String).toLocal(),
            };
    } catch (_) {
      _seen = {};
    }
  }

  static Future<void> _saveSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _seenKey,
        jsonEncode({
          for (final e in _seen.entries)
            e.key: e.value.toUtc().toIso8601String(),
        }),
      );
    } catch (_) {}
  }

  /// Counts messages that arrived while the app was closed.
  static Future<void> _countMissed() async {
    try {
      final me = DirectMessageService.myId;
      final rows = await Supabase.instance.client
          .from('direct_messages')
          .select()
          .eq('recipient_id', me)
          .gt('created_at', _since.toUtc().toIso8601String())
          .order('created_at', ascending: false)
          .limit(200);
      final counts = <String, int>{};
      for (final row in rows) {
        final m = DirectMessage.fromRow(row);
        if (m.senderId == _openWith) continue;
        final seen = _seen[m.senderId];
        if (seen != null && !m.createdAt.isAfter(seen)) continue;
        counts[m.senderId] = (counts[m.senderId] ?? 0) + 1;
      }
      unread.value = counts;
    } catch (error) {
      // The table may not exist yet; nothing to count.
      debugPrint('Unread messages: $error');
    }
  }

  static Future<void> _onNew(DirectMessage message) async {
    final from = message.senderId;
    // Already reading this conversation: the chat shows it (and plays its
    // own sound).
    if (from == _openWith) {
      markRead(from);
      return;
    }
    unread.value = {...unread.value, from: (unread.value[from] ?? 0) + 1};
    SfxService.play(Sfx.message);
    try {
      final profile = _profiles[from] ??= await ProfileService.fetchById(from);
      alert.value = DmAlert(from: profile, message: message);
    } catch (_) {
      // No name to show; the badge still counts it.
    }
  }

  /// A conversation was opened (or is on screen): it's all read.
  static void opened(String friendId) {
    _openWith = friendId;
    markRead(friendId);
    if (alert.value?.from.id == friendId) alert.value = null;
  }

  /// The conversation on screen was closed.
  static void closed(String friendId) {
    if (_openWith == friendId) _openWith = null;
    markRead(friendId);
  }

  static void markRead(String friendId) {
    _seen[friendId] = DateTime.now();
    _saveSeen();
    if (unread.value.containsKey(friendId)) {
      unread.value = {...unread.value}..remove(friendId);
    }
  }

  /// Hides the banner.
  static void dismiss() => alert.value = null;
}
