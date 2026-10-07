import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'screen_engine.dart';

/// Screen sharing works in browsers and the Android app; other platforms
/// and tests get this engine, which does nothing.
ScreenEngine createScreenEngine(ScreenSignalSender send) => _NoScreen();

class _NoScreen implements ScreenEngine {
  @override
  bool get canShare => false;

  @override
  Future<void> startCapture({required void Function() onEnded}) async =>
      throw UnsupportedError(
        'Screen sharing works in the browser and the Android app.',
      );

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
  bool get hasSound => false;

  @override
  void setVolume(double volume) {}

  @override
  Future<ui.Image?> grabFrame() async => null;

  @override
  Widget? videoView() => null;
}
