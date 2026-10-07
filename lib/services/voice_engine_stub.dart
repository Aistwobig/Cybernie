import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'voice_engine.dart';

/// Voice chat works in browsers and the phone apps; other platforms and
/// tests get this engine, which does nothing.
VoiceEngine createVoiceEngine(SignalSender send) => _NoVoice();

Future<List<DeviceOption>> listMicrophones() async => const [];

Future<List<DeviceOption>> listCameras() async => const [];

Future<List<DeviceOption>> listSpeakers() async => const [];

bool canChooseSpeaker() => false;

class _NoVoice implements VoiceEngine {
  @override
  bool get supported => false;

  @override
  Future<void> start() async => throw UnsupportedError(
    'Voice chat works in the browser and the phone app.',
  );

  @override
  Future<void> stop() async {}

  @override
  Future<void> useMic(String? deviceId) async {}

  @override
  void setMic(bool on) {}

  @override
  Future<void> connect(String peerId, {required bool initiator}) async {}

  @override
  void disconnect(String peerId) {}

  @override
  Future<void> handleSignal(String fromId, Map<String, dynamic> signal) async {}

  @override
  void setVolume(String peerId, double volume) {}

  @override
  Set<String> get peers => const {};

  @override
  Set<String> speakers({required String me}) => const {};

  @override
  Future<void> setCamera(bool on) async => throw UnsupportedError(
    'The camera works in the browser and the phone app.',
  );

  @override
  Future<void> useCamera(String? deviceId) async {}

  @override
  Future<void> useSpeaker(String? deviceId) async {}

  @override
  bool hasVideo(String? peerId) => false;

  @override
  Future<ui.Image?> grabFrame(String? peerId) async => null;

  @override
  Widget? videoView(String? peerId) => null;
}
