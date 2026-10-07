import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Background music: assets/audio/home_theme2.mp3 (three songs, about 14
/// minutes, no silence between them) looping across every screen, at a
/// volume chosen in the Home menu and remembered on this device.
///
/// Keep the file small (around 10 MB at most): browsers stream it, and a
/// huge file can stall mid-way, which they treat as the end of the song,
/// so the loop jumps back to the start.
///
/// Browsers don't let a page play sound until the player has clicked or
/// tapped something, so if the music can't start right away it starts on
/// the first tap.
class MusicService {
  MusicService._();

  /// Relative to assets/ (audioplayers adds that prefix).
  static const String _song = 'audio/home_theme2.mp3';
  static const String _volumeKey = 'music_volume';
  static const double defaultVolume = 0.5;

  /// 0 (off) to 1 (full).
  static final ValueNotifier<double> volume = ValueNotifier(defaultVolume);

  static AudioPlayer? _player;
  static bool _waitingForTap = false;

  /// How much of [volume] actually plays: below 1 while something talks or
  /// plays over the music (voice chat, a shared screen's sound), so they
  /// don't drown each other out. Each asks for its own level ([duck]); the
  /// quietest wins.
  static final Map<String, double> _ducks = {};
  static double get _duck =>
      _ducks.values.fold(1.0, (lowest, f) => f < lowest ? f : lowest);

  static double get _playing => volume.value * _duck;

  /// Plays the music at [factor] times its volume while [reason] needs it
  /// (1 = done), without changing the saved volume.
  static Future<void> duck(double factor, {String reason = 'voice'}) async {
    final before = _duck;
    if (factor >= 1) {
      _ducks.remove(reason);
    } else {
      _ducks[reason] = factor;
    }
    if (_duck == before) return;
    try {
      await _player?.setVolume(_playing);
    } catch (_) {}
  }

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

  /// Starts the music (if the volume isn't 0). Safe to call more than once.
  static Future<void> start() async {
    if (volume.value == 0) return;
    try {
      final player = _player ??= AudioPlayer();
      if (player.state == PlayerState.playing) return;
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(_playing);
      if (player.state == PlayerState.paused) {
        await player.resume();
      } else {
        await player.play(AssetSource(_song));
      }
    } catch (_) {
      // Usually the browser blocking sound before the first tap.
    }
    if (_player?.state != PlayerState.playing) _startOnFirstTap();
  }

  /// Retries [start] when the player next taps or clicks anywhere.
  static void _startOnFirstTap() {
    if (_waitingForTap) return;
    _waitingForTap = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  static void _onPointer(PointerEvent event) {
    if (event is! PointerUpEvent) return;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    _waitingForTap = false;
    start();
  }

  /// Changes the volume (0 to 1), saves it, and pauses at 0.
  static Future<void> setVolume(double value) async {
    final v = value.clamp(0.0, 1.0);
    volume.value = v;
    final player = _player;
    try {
      if (v == 0) {
        await player?.pause();
      } else {
        await player?.setVolume(_playing);
        if (player?.state != PlayerState.playing) await start();
      }
    } catch (_) {}
  }

  /// Saves the current volume (call when the slider is let go, not on
  /// every step).
  static Future<void> saveVolume() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_volumeKey, volume.value);
    } catch (_) {}
  }
}
