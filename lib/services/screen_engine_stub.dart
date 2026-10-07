import 'dart:ui' as ui;

import 'screen_engine.dart';

/// Screen sharing is web-only (the app is built for the web); other
/// platforms and tests get this engine, which does nothing.
ScreenEngine createScreenEngine(ScreenSignalSender send) => _NoScreen();

class _NoScreen implements ScreenEngine {
  @override
  bool get canShare => false;

  @override
  Future<void> startCapture({required void Function() onEnded}) async =>
      throw UnsupportedError('Screen sharing works in the web version.');

  @override
  Future<void> stop() async {}

  @override
  Future<void> offerTo(String peerId) async {}

  @override
  void drop(String peerId) {}

  @override
  Set<String> get peers => const {};

  @override
  Future<void> handleSignal(String fromId, Map<String, dynamic> signal) async {}

  @override
  Future<ui.Image?> grabFrame() async => null;
}
