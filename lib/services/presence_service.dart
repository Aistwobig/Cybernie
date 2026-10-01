import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Keeps the signed-in player's `last_seen_at` fresh while the app is open,
/// which is what makes them show as online to their friends.
class PresenceService {
  PresenceService._();

  static const Duration _interval = Duration(seconds: 60);

  static Timer? _timer;
  static StreamSubscription<AuthState>? _authSubscription;

  /// Call once at startup, after Supabase.initialize.
  static void start() {
    final auth = Supabase.instance.client.auth;
    _authSubscription ??= auth.onAuthStateChange.listen((state) {
      if (state.session == null) {
        _stopHeartbeat();
      } else {
        _startHeartbeat();
      }
    });
    if (auth.currentSession != null) _startHeartbeat();
  }

  static void _startHeartbeat() {
    if (_timer != null) return;
    _touch();
    _timer = Timer.periodic(_interval, (_) => _touch());
  }

  static void _stopHeartbeat() {
    _timer?.cancel();
    _timer = null;
  }

  static Future<void> _touch() async {
    try {
      await Supabase.instance.client.rpc('touch_last_seen');
    } catch (_) {
      // Offline or the migration isn't applied yet; try again next tick.
    }
  }
}
