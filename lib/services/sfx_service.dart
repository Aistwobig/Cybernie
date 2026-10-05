import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The game's little 8-bit sound effects (assets/audio/sfx_*.wav, generated
/// for this app, so no licensing to worry about).
enum Sfx {
  click('sfx_click'),
  pop('sfx_pop'),
  sit('sfx_sit'),
  stand('sfx_stand'),
  message('sfx_message'),
  sparkle('sfx_sparkle'),
  coin('sfx_coin'),
  join('sfx_join'),
  // Footsteps on the tavern boards (alternated, left and right foot).
  step1('sfx_step1'),
  step2('sfx_step2'),
  // Bernie's blackjack table.
  shuffle('sfx_shuffle'),
  card('sfx_card'),
  win('sfx_win'),
  lose('sfx_lose');

  const Sfx(this.file);

  final String file;
}

/// Plays [Sfx] at the volume chosen in the Home menu (remembered on this
/// device). Nothing plays until the player has clicked or tapped once;
/// browsers block sound before that, and a blocked sound is simply skipped.
class SfxService {
  SfxService._();

  static const String _volumeKey = 'sfx_volume';
  static const double defaultVolume = 0.6;

  /// 0 (off) to 1 (full).
  static final ValueNotifier<double> volume = ValueNotifier(defaultVolume);

  /// A few players taken in turn, so quick sounds can overlap.
  static final List<AudioPlayer> _pool = [];
  static const int _poolSize = 6;
  static int _next = 0;

  /// Reads the saved volume. Call before runApp.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      volume.value = (prefs.getDouble(_volumeKey) ?? defaultVolume).clamp(
        0.0,
        1.0,
      );
    } catch (_) {
      // No storage (e.g. private browsing): keep the default.
    }
  }

  /// Plays [sfx] once (quieter with [gain] below 1).
  static Future<void> play(Sfx sfx, {double gain = 1}) async {
    final v = volume.value * gain;
    if (v <= 0) return;
    try {
      if (_pool.isEmpty) {
        for (var i = 0; i < _poolSize; i++) {
          _pool.add(AudioPlayer()..setReleaseMode(ReleaseMode.stop));
        }
      }
      final player = _pool[_next];
      _next = (_next + 1) % _pool.length;
      await player.stop();
      await player.play(AssetSource('audio/${sfx.file}.wav'), volume: v);
    } catch (_) {
      // Usually the browser blocking sound before the first tap.
    }
  }

  /// Changes the volume (0 to 1) and plays a click at the new level so the
  /// player can hear it.
  static void setVolume(double value) {
    volume.value = value.clamp(0.0, 1.0);
  }

  /// Saves the current volume (call when the slider is let go).
  static Future<void> saveVolume() async {
    play(Sfx.click);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_volumeKey, volume.value);
    } catch (_) {}
  }
}
