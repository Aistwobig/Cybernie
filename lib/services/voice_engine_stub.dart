import 'voice_engine.dart';

/// Voice chat is web-only for now (the app is built for the web); other
/// platforms and tests get this engine, which does nothing.
VoiceEngine createVoiceEngine(SignalSender send) => _NoVoice();

class _NoVoice implements VoiceEngine {
  @override
  bool get supported => false;

  @override
  Future<void> start() async =>
      throw UnsupportedError('Voice chat works in the web version.');

  @override
  Future<void> stop() async {}

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
}
