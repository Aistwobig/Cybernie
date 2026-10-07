import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui' as ui;
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'screen_engine.dart';

ScreenEngine createScreenEngine(ScreenSignalSender send) => _WebScreen(send);

/// Free public servers that help two players find a route to each other.
final List<String> _stunServers = [
  'stun:stun.l.google.com:19302',
  'stun:stun1.l.google.com:19302',
];

class _Link {
  _Link(this.pc);

  final web.RTCPeerConnection pc;

  /// Network candidates that arrived before the offer/answer was set.
  final List<web.RTCIceCandidateInit> early = [];
  bool remoteSet = false;
}

class _WebScreen implements ScreenEngine {
  _WebScreen(this._send);

  final ScreenSignalSender _send;
  final Map<String, _Link> _links = {};

  /// Our captured screen (while sharing).
  web.MediaStream? _capture;

  /// The screen being shown: ours while sharing, otherwise the one we
  /// receive. Plays hidden; the game copies its frames.
  web.HTMLVideoElement? _video;

  /// The shared screen's sound, for viewers (the sharer already hears it).
  web.HTMLAudioElement? _sound;
  double _volume = 1;

  @override
  bool get hasSound => _sound != null;

  @override
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    _sound?.volume = _volume;
  }

  void _playSound(web.MediaStreamTrack track) {
    _stopSound();
    final sound = web.HTMLAudioElement()
      ..autoplay = true
      ..srcObject = (web.MediaStream()..addTrack(track))
      ..volume = _volume;
    sound.play().toDart.catchError((Object _) => null);
    _sound = sound;
  }

  void _stopSound() {
    _sound
      ?..pause()
      ..srcObject = null;
    _sound = null;
  }

  @override
  bool get canShare =>
      (web.window.navigator.mediaDevices as JSObject).has('getDisplayMedia');

  @override
  Set<String> get peers => _links.keys.toSet();

  @override
  Future<void> startCapture({required void Function() onEnded}) async {
    final constraints =
        {
              // Readable but light: everyone upstairs gets it straight from us.
              'video': {
                'width': {'ideal': 1280, 'max': 1920},
                'height': {'ideal': 720, 'max': 1080},
                'frameRate': {'ideal': 10, 'max': 15},
              },
              // Its sound too, where the browser can (Chrome / Edge: a tab's
              // sound, or the whole computer's on Windows; the picker has a
              // "share audio" switch). Not echoed back to us.
              'audio': {
                'echoCancellation': false,
                'noiseSuppression': false,
                'autoGainControl': false,
              },
              'systemAudio': 'include',
              'suppressLocalAudioPlayback': false,
            }.jsify()!
            as web.DisplayMediaStreamOptions;
    final stream = await web.window.navigator.mediaDevices
        .getDisplayMedia(constraints)
        .toDart;
    _capture = stream;
    final track = stream.getVideoTracks().toDart.first;
    // Text and slides: keep it sharp rather than smooth.
    track.contentHint = 'detail';
    // "Stop sharing" in the browser's own bar.
    track.onended = ((web.Event _) => onEnded()).toJS;
    _show(stream);
  }

  @override
  Future<void> stop() async {
    for (final id in _links.keys.toList()) {
      drop(id);
    }
    final capture = _capture;
    _capture = null;
    if (capture != null) {
      for (final t in capture.getTracks().toDart) {
        t.stop();
      }
    }
    _hide();
  }

  void _show(web.MediaStream stream) {
    _hide();
    final video = web.HTMLVideoElement()
      ..muted = true
      ..playsInline = true
      ..srcObject = stream;
    // On the page (browsers may pause a detached or off-screen video) but
    // invisible.
    video.style
      ..position = 'fixed'
      ..left = '0'
      ..bottom = '0'
      ..width = '1px'
      ..height = '1px'
      ..opacity = '0.01'
      ..setProperty('pointer-events', 'none');
    web.document.body?.append(video);
    video.play().toDart.catchError((Object _) => null);
    _video = video;
  }

  void _hide() {
    _video
      ?..pause()
      ..srcObject = null
      ..remove();
    _video = null;
    _stopSound();
  }

  web.RTCPeerConnection _newLink(String peerId) {
    final pc = web.RTCPeerConnection(
      web.RTCConfiguration(
        iceServers: [
          web.RTCIceServer(
            urls: [for (final url in _stunServers) url.toJS].toJS,
          ),
        ].toJS,
      ),
    );
    _links[peerId] = _Link(pc);
    pc.onicecandidate = ((web.RTCPeerConnectionIceEvent event) {
      final candidate = event.candidate;
      if (candidate == null) return;
      final init = candidate.toJSON();
      _send(peerId, {
        'kind': 'scr-ice',
        'candidate': init.candidate,
        'sdpMid': init.sdpMid,
        'sdpMLineIndex': init.sdpMLineIndex,
      });
    }).toJS;
    pc.ontrack = ((web.RTCTrackEvent event) {
      if (event.track.kind == 'video') {
        // _show replaces any earlier picture (and its sound), so keep the
        // sound if it arrived first.
        final sound = _sound;
        final soundTrack = sound == null
            ? null
            : (sound.srcObject as web.MediaStream?)?.getAudioTracks().toDart;
        _show(web.MediaStream()..addTrack(event.track));
        if (soundTrack != null && soundTrack.isNotEmpty) {
          _playSound(soundTrack.first);
        }
      } else if (event.track.kind == 'audio') {
        _playSound(event.track);
      }
    }).toJS;
    pc.onconnectionstatechange = ((web.Event _) {
      final state = pc.connectionState;
      if (state == 'failed' || state == 'closed') {
        debugPrint('Screen: link with $peerId $state');
        drop(peerId);
      }
    }).toJS;
    return pc;
  }

  @override
  Future<void> offerTo(String peerId) async {
    final capture = _capture;
    if (capture == null || _links.containsKey(peerId)) return;
    final pc = _newLink(peerId);
    // The picture, and the sound if it's being shared.
    for (final track in capture.getTracks().toDart) {
      pc.addTrack(track, capture);
    }
    await pc.setLocalDescription().toDart;
    final offer = pc.localDescription;
    if (offer == null) return;
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
          if (id != fromId) drop(id);
        }
        drop(fromId);
        final pc = _newLink(fromId);
        await pc
            .setRemoteDescription(
              web.RTCSessionDescriptionInit(
                type: 'offer',
                sdp: signal['sdp'] as String,
              ),
            )
            .toDart;
        await _flushEarly(fromId);
        await pc.setLocalDescription().toDart;
        final answer = pc.localDescription;
        if (answer == null) return;
        _send(fromId, {'kind': 'scr-answer', 'sdp': answer.sdp});
      case 'scr-answer':
        final link = _links[fromId];
        if (link == null) return;
        await link.pc
            .setRemoteDescription(
              web.RTCSessionDescriptionInit(
                type: 'answer',
                sdp: signal['sdp'] as String,
              ),
            )
            .toDart;
        await _flushEarly(fromId);
      case 'scr-ice':
        final link = _links[fromId];
        if (link == null) return;
        final init = web.RTCIceCandidateInit(
          candidate: signal['candidate'] as String? ?? '',
          sdpMid: signal['sdpMid'] as String?,
          sdpMLineIndex: (signal['sdpMLineIndex'] as num?)?.toInt(),
        );
        if (link.remoteSet) {
          await link.pc.addIceCandidate(init).toDart;
        } else {
          link.early.add(init);
        }
      case 'scr-bye':
        drop(fromId);
    }
  }

  Future<void> _flushEarly(String peerId) async {
    final link = _links[peerId];
    if (link == null) return;
    link.remoteSet = true;
    for (final init in link.early) {
      await link.pc.addIceCandidate(init).toDart;
    }
    link.early.clear();
  }

  @override
  Future<ui.Image?> grabFrame() async {
    final video = _video;
    // 2 = HAVE_CURRENT_DATA: a frame is ready.
    if (video == null || video.readyState < 2 || video.videoWidth == 0) {
      return null;
    }
    if (video.paused) video.play().toDart.catchError((Object _) => null);
    return ui_web.createImageFromTextureSource(
      video,
      width: video.videoWidth,
      height: video.videoHeight,
    );
  }
}
