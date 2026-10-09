import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Widget;

import 'room_service.dart';
import 'screen_engine.dart';

/// Sharing a screen on the projector upstairs, one player at a time.
///
/// The sharer is flagged in the room's Presence. Their browser captures the
/// screen and sends it straight to every player upstairs (a video link
/// each, set up over the room's channel like voice calls); viewers only
/// accept it from whoever is sharing.
class ScreenShareService {
  ScreenShareService();

  /// We're sharing our screen.
  final ValueNotifier<bool> sharing = ValueNotifier(false);

  /// Who is sharing (a player id; [myId] for us), or null.
  final ValueNotifier<String?> sharerId = ValueNotifier(null);

  RoomService? _room;
  String? myId;
  ScreenEngine? _engine;

  ScreenEngine _engineFor(RoomService room) => _engine ??= ScreenEngine(
    (to, signal) => room.sendVoiceSignal(to, signal),
  );

  /// Whether this browser can share its screen (computer browsers).
  bool get canShare => _engine?.canShare ?? ScreenEngine((_, _) {}).canShare;

  /// Starts sharing (the browser asks which screen, window or tab). Throws
  /// a readable message if it can't, e.g. when someone else is sharing.
  Future<void> start(
    RoomService room, {
    required List<RoomPlayer> others,
    required void Function() onStoppedByBrowser,
  }) async {
    if (sharing.value) return;
    final current = [
      for (final p in others)
        if (p.sharingScreen) p,
    ];
    if (current.isNotEmpty) throw ScreenShareBusy(current.first.name);
    _room = room;
    myId = room.myId;
    final engine = _engineFor(room);
    if (!engine.canShare) {
      throw const ScreenShareUnsupported();
    }
    try {
      await engine.startCapture(onEnded: onStoppedByBrowser);
    } catch (error) {
      debugPrint('Screen: $error');
      // Picking nothing in the browser's picker isn't an error to show.
      if ('$error'.contains('NotAllowedError') ||
          '$error'.contains('AbortError')) {
        throw const ScreenShareCancelled();
      }
      rethrow;
    }
    sharing.value = true;
    sharerId.value = myId;
    _since = DateTime.now().millisecondsSinceEpoch;
    await room.setScreen(true, since: _since);
  }

  int _since = 0;

  Future<void> stop() async {
    if (!sharing.value) return;
    final engine = _engine;
    final room = _room;
    sharing.value = false;
    if (sharerId.value == myId) sharerId.value = null;
    if (engine != null) {
      for (final peer in engine.peers) {
        room?.sendVoiceSignal(peer, {'kind': 'scr-bye'});
      }
      await engine.stop();
    }
    await room?.setScreen(false);
  }

  /// A link setup message from another player ('scr-...' kinds).
  void handleSignal(
    RoomService room,
    String fromId,
    Map<String, dynamic> signal,
  ) {
    _room ??= room;
    myId ??= room.myId;
    final engine = _engineFor(room);
    // A viewer upstairs has no picture yet (e.g. our first offer reached
    // them before they knew we were sharing, so they ignored it): send a
    // fresh one.
    if (signal['kind'] == 'scr-want') {
      if (sharing.value && _viewers.contains(fromId)) {
        engine.drop(fromId);
        engine.offerTo(fromId);
      }
      return;
    }
    // Only take a picture from whoever is sharing.
    if (signal['kind'] == 'scr-offer' && sharerId.value != fromId) return;
    engine.handleSignal(fromId, signal).catchError((Object error) {
      debugPrint('Screen signal from $fromId: $error');
    });
  }

  /// Called every second or so: works out who is sharing; as the sharer,
  /// links to everyone upstairs ([viewers]) and drops anyone who left; if
  /// someone else started first, gives way ([onLostToEarlier] with their
  /// name).
  void update({
    required List<RoomPlayer> others,
    required Set<String> viewers,
    RoomService? room,
    bool upstairs = false,
    void Function(String name)? onLostToEarlier,
  }) {
    if (room != null) {
      _room ??= room;
      myId ??= room.myId;
    }
    _viewers = viewers;
    final engine = _engine;
    final others0 = [
      for (final p in others)
        if (p.sharingScreen) p,
    ]..sort((a, b) => a.screenSince.compareTo(b.screenSince));
    final other = others0.isEmpty ? null : others0.first;
    if (sharing.value) {
      // Two started at once: the earlier one keeps it.
      if (other != null && other.screenSince < _since) {
        stop();
        onLostToEarlier?.call(other.name);
        sharerId.value = other.id;
        return;
      }
      if (engine == null) return;
      for (final id in viewers) {
        if (!engine.peers.contains(id)) engine.offerTo(id);
      }
      for (final id in engine.peers) {
        if (!viewers.contains(id)) {
          _room?.sendVoiceSignal(id, {'kind': 'scr-bye'});
          engine.drop(id);
        }
      }
      return;
    }
    final sharer = other?.id;
    if (sharer != sharerId.value) {
      // The share ended or changed hands: drop the old picture.
      if (engine != null) {
        for (final id in engine.peers) {
          if (id != sharer) engine.drop(id);
        }
      }
      sharerId.value = sharer;
    }
    // Upstairs while someone shares, but no picture from them: ask for it
    // (every few seconds until it comes).
    final linked = engine?.peers.contains(sharer) ?? false;
    if (sharer == null || !upstairs || linked) return;
    final now = DateTime.now();
    if (now.difference(_lastAsked) < _askEvery) return;
    _lastAsked = now;
    _room?.sendVoiceSignal(sharer, {'kind': 'scr-want'});
  }

  /// The players upstairs, as of the last [update] (the sharer only sends
  /// to them).
  Set<String> _viewers = const {};

  DateTime _lastAsked = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _askEvery = Duration(seconds: 3);

  /// Whether a shared screen's sound is playing for us.
  bool get hasSound => _engine?.hasSound ?? false;

  /// How loud a shared screen's sound plays, 0 to 1.
  void setVolume(double volume) => _engine?.setVolume(volume);

  /// The latest frame of the shared screen, or null. The caller disposes it.
  Future<ui.Image?> grabFrame() async {
    if (sharerId.value == null) return null;
    return _engine?.grabFrame();
  }

  /// In the Android app: a live view of the shared screen, for the tavern
  /// to place over the projector. Null on the web.
  Widget? videoView() => sharerId.value == null ? null : _engine?.videoView();

  Future<void> dispose() async {
    await stop();
    await _engine?.stop();
  }
}

/// Someone else ([name]) is already sharing.
class ScreenShareBusy implements Exception {
  const ScreenShareBusy(this.name);
  final String name;
}

/// This browser can't share its screen (most phones).
class ScreenShareUnsupported implements Exception {
  const ScreenShareUnsupported();
}

/// The player closed the browser's picker without choosing anything.
class ScreenShareCancelled implements Exception {
  const ScreenShareCancelled();
}
