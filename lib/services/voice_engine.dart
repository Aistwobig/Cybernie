/// The low-level part of voice chat: the microphone and one direct
/// (WebRTC) call per nearby player. VoiceService decides who to call.
library;

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'voice_engine_stub.dart'
    if (dart.library.js_interop) 'voice_engine_web.dart'
    if (dart.library.io) 'voice_engine_native.dart'
    as impl;

/// Sends a call setup message (offer / answer / candidate) to a player.
typedef SignalSender = void Function(String toId, Map<String, dynamic> signal);

/// A microphone or camera the player can pick (label is empty until the
/// browser has been allowed to use that kind of device once).
class DeviceOption {
  const DeviceOption(this.id, this.label);

  final String id;
  final String label;
}

/// The microphones on this device.
Future<List<DeviceOption>> listMicrophones() => impl.listMicrophones();

/// The cameras on this device.
Future<List<DeviceOption>> listCameras() => impl.listCameras();

/// The speakers / headphones on this device.
Future<List<DeviceOption>> listSpeakers() => impl.listSpeakers();

/// Whether this browser lets a page pick where sound plays (most phone
/// browsers don't: there the system decides).
bool canChooseSpeaker() => impl.canChooseSpeaker();

abstract class VoiceEngine {
  /// The browser's engine on the web, flutter_webrtc's in the phone apps;
  /// elsewhere one that isn't supported.
  factory VoiceEngine(SignalSender send) => impl.createVoiceEngine(send);

  bool get supported;

  /// Opens the microphone (the browser asks permission the first time).
  Future<void> start();

  /// Hangs up every call and closes the microphone.
  Future<void> stop();

  /// Uses microphone [deviceId] (null: the default one), switching it live
  /// in every call if we're already talking.
  Future<void> useMic(String? deviceId);

  /// Plays everyone's voices on speaker [deviceId] (null: the default one).
  Future<void> useSpeaker(String? deviceId);

  /// Mutes or unmutes our microphone in every call.
  void setMic(bool on);

  /// Calls [peerId] ([initiator]: we send the offer).
  Future<void> connect(String peerId, {required bool initiator});

  void disconnect(String peerId);

  /// A call setup message from [fromId].
  Future<void> handleSignal(String fromId, Map<String, dynamic> signal);

  /// How loud [peerId]'s voice plays, 0 to 1.
  void setVolume(String peerId, double volume);

  /// Players we're in a call with.
  Set<String> get peers;

  /// Who is making sound right now: player ids, plus [me] for us.
  Set<String> speakers({required String me});

  /// Turns our camera on or off in every call (the browser asks
  /// permission the first time).
  Future<void> setCamera(bool on);

  /// Uses camera [deviceId] (null: the default one), switching it live in
  /// every call if our camera is on.
  Future<void> useCamera(String? deviceId);

  /// Whether a video picture exists for [peerId] (null: our own camera).
  bool hasVideo(String? peerId);

  /// The latest frame of [peerId]'s camera (null: our own), or null if
  /// there's none yet. The caller disposes it.
  Future<ui.Image?> grabFrame(String? peerId);

  /// In the phone apps, where frames can't be copied into the game: a live
  /// view of [peerId]'s camera (null: ours), which the tavern places over
  /// the camera picture. Null on the web (see [grabFrame]).
  Widget? videoView(String? peerId);
}
