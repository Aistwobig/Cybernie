import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

import 'screen_engine.dart';
import 'screen_engine_stub.dart' as stub;

/// The Android app's engine (flutter_webrtc), speaking the same link setup
/// messages as the browser's, so app and web players see each other's
/// screens. Elsewhere (desktop, tests) screen sharing stays off.
ScreenEngine createScreenEngine(ScreenSignalSender send) =>
    Platform.isAndroid ? _NativeScreen(send) : stub.createScreenEngine(send);

/// Free public servers that help two players find a route to each other.
const List<String> _stunServers = [
  'stun:stun.l.google.com:19302',
  'stun:stun1.l.google.com:19302',
];

/// Starts and stops the "you are sharing your screen" notification Android
/// requires while capturing (ScreenCaptureService in the Android project).
const MethodChannel _captureService = MethodChannel('cybernie/screen_capture');

class _Link {
  _Link(this.pc);

  final rtc.RTCPeerConnection pc;

  /// Network candidates that arrived before the offer/answer was set.
  final List<rtc.RTCIceCandidate> early = [];
  bool remoteSet = false;
}

class _NativeScreen implements ScreenEngine {
  _NativeScreen(this._send);

  final ScreenSignalSender _send;
  final Map<String, _Link> _links = {};

  /// Our captured screen (while sharing).
  rtc.MediaStream? _capture;

  /// The screen being shown: ours while sharing, otherwise the one we
  /// receive.
  rtc.RTCVideoRenderer? _video;

  /// The shared screen's sound, for viewers.
  rtc.MediaStreamTrack? _sound;
  double _volume = 1;

  @override
  bool get hasSound => _sound != null;

  @override
  void setVolume(double volume) {
    final v = volume.clamp(0.0, 1.0);
    if ((v - _volume).abs() < 0.02) return;
    _volume = v;
    _applyVolume();
  }

  void _applyVolume() {
    final sound = _sound;
    if (sound == null) return;
    // On Android, 10 is full volume.
    rtc.Helper.setVolume(_volume * 10, sound).catchError((Object _) {});
  }

  @override
  bool get canShare => true;

  @override
  Set<String> get peers => _links.keys.toSet();

  @override
  Future<void> startCapture({required void Function() onEnded}) async {
    // Android's "start recording or casting?" question first; the capture
    // notification may only start once it's been answered yes.
    if (!await rtc.Helper.requestCapturePermission()) {
      throw StateError('NotAllowedError: screen capture declined');
    }
    await _captureService.invokeMethod<void>('start');
    try {
      // Android can't capture the phone's own sound: the picture only.
      final stream = await rtc.navigator.mediaDevices.getDisplayMedia({
        'video': true,
        'audio': false,
      });
      _capture = stream;
      final track = stream.getVideoTracks().first;
      // Android's own "stop sharing" (in the notification shade).
      track.onEnded = onEnded;
      await _show(stream);
    } catch (_) {
      await _captureService.invokeMethod<void>('stop');
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    for (final id in _links.keys.toList()) {
      drop(id);
    }
    final capture = _capture;
    _capture = null;
    if (capture != null) {
      for (final t in capture.getTracks()) {
        await t.stop();
      }
      await capture.dispose();
      await _captureService.invokeMethod<void>('stop');
    }
    await _hide();
  }

  Future<void> _show(rtc.MediaStream stream) async {
    final old = _video;
    final renderer = rtc.RTCVideoRenderer();
    await renderer.initialize();
    renderer.srcObject = stream;
    _video = renderer;
    await old?.dispose();
  }

  Future<void> _hide() async {
    final video = _video;
    _video = null;
    _sound = null;
    await video?.dispose();
  }

  Future<rtc.RTCPeerConnection> _newLink(String peerId) async {
    final pc = await rtc.createPeerConnection({
      'iceServers': [
        {'urls': _stunServers},
      ],
      'sdpSemantics': 'unified-plan',
    });
    _links[peerId] = _Link(pc);
    pc.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      _send(peerId, {
        'kind': 'scr-ice',
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };
    pc.onTrack = (event) async {
      final track = event.track;
      if (track.kind == 'video') {
        final stream = event.streams.isNotEmpty
            ? event.streams.first
            : (await rtc.createLocalMediaStream('scr-$peerId')
                ..addTrack(track));
        final sound = _sound;
        await _show(stream);
        // _show keeps the sound, which may have arrived first.
        _sound = sound;
      } else if (track.kind == 'audio') {
        // Plays by itself; kept for its volume.
        _sound = track;
        _applyVolume();
      }
    };
    pc.onConnectionState = (state) {
      if (state == rtc.RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == rtc.RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        debugPrint('Screen: link with $peerId $state');
        drop(peerId);
      }
    };
    return pc;
  }

  @override
  Future<void> offerTo(String peerId) async {
    final capture = _capture;
    if (capture == null || _links.containsKey(peerId)) return;
    final pc = await _newLink(peerId);
    for (final track in capture.getTracks()) {
      await pc.addTrack(track, capture);
    }
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    _send(peerId, {'kind': 'scr-offer', 'sdp': offer.sdp});
  }

  @override
  void drop(String peerId) {
    final link = _links.remove(peerId);
    if (link == null) return;
    link.pc.close();
    // A viewer whose link to the sharer closed has nothing to show.
    if (_capture == null && _links.isEmpty) _hide();
  }

  @override
  Future<void> handleSignal(String fromId, Map<String, dynamic> signal) async {
    switch (signal['kind']) {
      case 'scr-offer':
        // A new share replaces whatever we were watching.
        for (final id in _links.keys.toList()) {
          drop(id);
        }
        final pc = await _newLink(fromId);
        await pc.setRemoteDescription(
          rtc.RTCSessionDescription(signal['sdp'] as String, 'offer'),
        );
        await _flushEarly(fromId);
        final answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);
        _send(fromId, {'kind': 'scr-answer', 'sdp': answer.sdp});
      case 'scr-answer':
        final link = _links[fromId];
        if (link == null) return;
        await link.pc.setRemoteDescription(
          rtc.RTCSessionDescription(signal['sdp'] as String, 'answer'),
        );
        await _flushEarly(fromId);
      case 'scr-ice':
        final link = _links[fromId];
        if (link == null) return;
        final candidate = rtc.RTCIceCandidate(
          signal['candidate'] as String? ?? '',
          signal['sdpMid'] as String?,
          (signal['sdpMLineIndex'] as num?)?.toInt(),
        );
        if (link.remoteSet) {
          await link.pc.addCandidate(candidate);
        } else {
          link.early.add(candidate);
        }
      case 'scr-bye':
        drop(fromId);
    }
  }

  Future<void> _flushEarly(String peerId) async {
    final link = _links[peerId];
    if (link == null) return;
    link.remoteSet = true;
    for (final candidate in link.early) {
      await link.pc.addCandidate(candidate);
    }
    link.early.clear();
  }

  /// Frames can't be copied out of the phone's video: the tavern shows
  /// [videoView] instead.
  @override
  Future<ui.Image?> grabFrame() async => null;

  @override
  Widget? videoView() {
    final renderer = _video;
    if (renderer == null) return null;
    return rtc.RTCVideoView(
      renderer,
      objectFit: rtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
    );
  }
}
