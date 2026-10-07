import 'dart:ui' as ui;

import 'voice_engine.dart';

/// Voice chat is web-only for now (the app is built for the web); other
/// platforms and tests get this engine, which does nothing.
VoiceEngine createVoiceEngine(SignalSender send) => _NoVoice();

Future<List<DeviceOption>> listMicrophones() async => const [];

Future<List<DeviceOption>> listCameras() async => const [];

class _NoVoice implements VoiceEngine {
  @override
  bool get supported => false;

  @override
  Future<void> start() async =>
      throw UnsupportedError('Voice chat works in the web version.');

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
  Future<void> setCamera(bool on) async =>
      throw UnsupportedError('The camera works in the web version.');

  @override
  Future<void> useCamera(String? deviceId) async {}

  @override
  bool hasVideo(String? peerId) => false;

  @override
  Future<ui.Image?> grabFrame(String? peerId) async => null;
}
