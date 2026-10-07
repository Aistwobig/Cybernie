import 'dart:math' as math;

import 'package:flame/components.dart' show Vector2;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'music_service.dart';
import 'room_service.dart';
import 'voice_engine.dart';

enum VoiceState { off, connecting, on }

/// Proximity voice chat in a tavern room, directly between players.
///
/// Players who joined voice are flagged in the room's Presence. We call
/// (WebRTC) only the ones within [connectRange] of us, hang up past
/// [hangUpRange], and each voice fades with distance. Call setup messages
/// travel over the room's Supabase channel; the voice itself goes player to
/// player and never touches a server.
class VoiceService {
  VoiceService();

  final ValueNotifier<VoiceState> state = ValueNotifier(VoiceState.off);
  final ValueNotifier<bool> micOn = ValueNotifier(false);

  /// Who is talking right now (player ids; [myId] for us).
  final ValueNotifier<Set<String>> speaking = ValueNotifier(const {});

  /// Our camera is on.
  final ValueNotifier<bool> cameraOn = ValueNotifier(false);
  bool _cameraBusy = false;

  /// Players in our call whose camera picture we can show right now.
  final ValueNotifier<Set<String>> watching = ValueNotifier(const {});

  /// Full volume within [_near] map pixels, silent from [_far].
  static const double _near = 110;
  static const double _far = 420;
  static const double connectRange = 450;
  static const double hangUpRange = 550;

  /// How loud other players' voices are overall, 0 to 1 (Settings), on top
  /// of how far away they are. Remembered on this device.
  static final ValueNotifier<double> volume = ValueNotifier(1);
  static const String _volumeKey = 'voice_volume';

  /// Reads the saved voice volume. Call before runApp.
  static Future<void> loadVolume() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      volume.value = (prefs.getDouble(_volumeKey) ?? 1).clamp(0.0, 1.0);
      micId.value = prefs.getString(_micKey);
      cameraId.value = prefs.getString(_cameraKey);
    } catch (_) {}
  }

  static void setVolume(double value) => volume.value = value.clamp(0.0, 1.0);

  /// The microphone picked in Settings (null: the device's default).
  /// Remembered on this device.
  static final ValueNotifier<String?> micId = ValueNotifier(null);
  static const String _micKey = 'voice_mic';

  /// The voice chat in progress, so a new mic choice switches it live.
  static VoiceService? _active;

  static Future<List<DeviceOption>> microphones() => listMicrophones();

  static Future<void> chooseMic(String? id) async {
    micId.value = id;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (id == null) {
        await prefs.remove(_micKey);
      } else {
        await prefs.setString(_micKey, id);
      }
    } catch (_) {}
    try {
      await _active?._engine?.useMic(id);
    } catch (error) {
      debugPrint('Switching mic: $error');
    }
  }

  /// The camera picked in Settings (null: the device's default, the front
  /// camera on phones). Remembered on this device.
  static final ValueNotifier<String?> cameraId = ValueNotifier(null);
  static const String _cameraKey = 'voice_camera';

  static Future<List<DeviceOption>> cameras() => listCameras();

  static Future<void> chooseCamera(String? id) async {
    cameraId.value = id;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (id == null) {
        await prefs.remove(_cameraKey);
      } else {
        await prefs.setString(_cameraKey, id);
      }
    } catch (_) {}
    try {
      await _active?._engine?.useCamera(id);
    } catch (error) {
      debugPrint('Switching camera: $error');
    }
  }

  static Future<void> saveVolume() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_volumeKey, volume.value);
    } catch (_) {}
  }

  RoomService? _room;
  String? myId;
  VoiceEngine? _engine;

  /// A nearby player came into our voice chat (walked close, or joined).
  void Function(String playerId)? onPeerJoined;

  /// A player dropped out of our voice chat (walked away, or left).
  void Function(String playerId)? onPeerLeft;

  /// Joins voice chat in [room] with the mic on. Throws a readable message
  /// if it can't (no permission, not supported, ...).
  Future<void> join(RoomService room) async {
    if (state.value != VoiceState.off) return;
    state.value = VoiceState.connecting;
    _room = room;
    myId = room.myId;
    final engine = VoiceEngine(
      (to, signal) => room.sendVoiceSignal(to, signal),
    );
    _engine = engine;
    _active = this;
    try {
      await engine.useMic(micId.value);
      await engine.useCamera(cameraId.value);
      await engine.start();
      await room.setVoice(true);
      micOn.value = true;
      state.value = VoiceState.on;
    } catch (error) {
      debugPrint('Voice: $error');
      await leave();
      throw _explain(error);
    }
  }

  Future<void> leave() async {
    final engine = _engine;
    final room = _room;
    _engine = null;
    if (identical(_active, this)) _active = null;
    state.value = VoiceState.off;
    micOn.value = false;
    cameraOn.value = false;
    speaking.value = const {};
    watching.value = const {};
    MusicService.duck(1);
    if (engine != null) {
      for (final peer in engine.peers) {
        room?.sendVoiceSignal(peer, {'kind': 'bye'});
      }
      await engine.stop();
      await room?.setVoice(false);
    }
  }

  void setMic(bool on) {
    _engine?.setMic(on);
    micOn.value = on;
  }

  /// Turns our camera on or off (while in voice chat). Throws a readable
  /// message if it can't.
  Future<void> setCamera(bool on) async {
    final engine = _engine;
    if (engine == null || _cameraBusy || on == cameraOn.value) return;
    _cameraBusy = true;
    try {
      await engine.setCamera(on);
      cameraOn.value = on;
      await _room?.setCamera(on);
    } catch (error) {
      debugPrint('Camera: $error');
      throw _explain(error, camera: true);
    } finally {
      _cameraBusy = false;
    }
  }

  /// The latest frame of [playerId]'s camera (null: ours), if there is one.
  /// The caller disposes it.
  Future<ui.Image?> grabFrame(String? playerId) async =>
      _engine?.grabFrame(playerId);

  /// A call setup message from another player.
  void handleSignal(String fromId, Map<String, dynamic> signal) {
    final engine = _engine;
    if (engine == null || state.value != VoiceState.on) return;
    engine.handleSignal(fromId, signal).catchError((Object error) {
      debugPrint('Voice signal from $fromId: $error');
    });
  }

  /// Called a few times a second: calls players who came close, hangs up on
  /// those who walked away, and sets each voice's volume by distance.
  /// [voicePlayers] are the players in voice chat, [positions] where
  /// everyone is, [me] where we are.
  void update({
    required Vector2 me,
    required Map<String, Vector2> positions,
    required Set<String> voicePlayers,
    Set<String> cameraPlayers = const {},
  }) {
    final engine = _engine;
    final self = myId;
    if (engine == null || self == null || state.value != VoiceState.on) {
      return;
    }
    final connected = engine.peers;
    for (final id in voicePlayers) {
      final at = positions[id];
      if (at == null || id == self) continue;
      final distance = me.distanceTo(at);
      if (!connected.contains(id) && distance <= connectRange) {
        // The player with the "smaller" id starts, so only one side does.
        engine.connect(id, initiator: self.compareTo(id) < 0);
        onPeerJoined?.call(id);
      } else if (connected.contains(id) && distance > hangUpRange) {
        _room?.sendVoiceSignal(id, {'kind': 'bye'});
        engine.disconnect(id);
        onPeerLeft?.call(id);
      }
      engine.setVolume(id, volumeAt(distance) * volume.value);
    }
    // Anyone who left voice (or the room): hang up.
    for (final id in connected) {
      if (!voicePlayers.contains(id) || !positions.containsKey(id)) {
        engine.disconnect(id);
        onPeerLeft?.call(id);
      }
    }
    final talking = engine.speakers(me: self);
    if (!setEquals(talking, speaking.value)) speaking.value = talking;
    final seen = {
      for (final id in engine.peers)
        if (cameraPlayers.contains(id) && engine.hasVideo(id)) id,
    };
    if (!setEquals(seen, watching.value)) watching.value = seen;
    // Turn the music down while we're in a call with anyone nearby, so it
    // doesn't drown out their voices.
    MusicService.duck(engine.peers.isEmpty ? 1 : musicDuring);
  }

  /// How loud the music plays during a voice call (of its normal volume).
  static const double musicDuring = 0.25;

  /// Volume for a voice [distance] map pixels away: full up close, fading
  /// quickly, silent from [_far].
  static double volumeAt(double distance) {
    final t = ((distance - _near) / (_far - _near)).clamp(0.0, 1.0);
    return math.pow(1 - t, 2).toDouble();
  }

  static String _explain(Object error, {bool camera = false}) {
    final text = '$error';
    if (text.contains('NotAllowedError') || text.contains('Permission')) {
      return camera
          ? 'Allow the camera to turn it on.'
          : 'Allow the microphone to use voice chat.';
    }
    if (text.contains('NotFoundError')) {
      return camera ? 'No camera found.' : 'No microphone found.';
    }
    if (text.contains('NotReadableError')) {
      return camera
          ? 'Your camera is being used by another app.'
          : 'Your microphone is being used by another app.';
    }
    if (text.contains('web version')) {
      return camera
          ? 'The camera works in the web version.'
          : 'Voice chat works in the web version.';
    }
    return camera
        ? "Couldn't turn on the camera. Try again."
        : "Couldn't start voice chat. Try again.";
  }
}
