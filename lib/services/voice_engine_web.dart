import 'dart:js_interop';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'voice_engine.dart';

VoiceEngine createVoiceEngine(SignalSender send) => _WebVoice(send);

/// Free public servers that help two players find a route to each other.
/// (Strict networks may also need a relay "TURN" server: add it here.)
final List<String> _stunServers = [
  'stun:stun.l.google.com:19302',
  'stun:stun1.l.google.com:19302',
];

/// One call: the connection, the <audio> element their voice plays in, and
/// a level meter for the talking indicator.
class _Call {
  _Call(this.pc);

  final web.RTCPeerConnection pc;
  web.HTMLAudioElement? audio;
  web.AnalyserNode? meter;

  /// Network candidates that arrived before the offer/answer was set.
  final List<web.RTCIceCandidateInit> early = [];
  bool remoteSet = false;
  double volume = 1;
}

class _WebVoice implements VoiceEngine {
  _WebVoice(this._send);

  final SignalSender _send;
  web.MediaStream? _mic;
  web.AudioContext? _audio;
  web.AnalyserNode? _myMeter;
  bool _micOn = true;
  final Map<String, _Call> _calls = {};

  @override
  bool get supported => true;

  @override
  Set<String> get peers => _calls.keys.toSet();

  @override
  Future<void> start() async {
    if (_mic != null) return;
    final constraints = {
      'echoCancellation': true,
      'noiseSuppression': true,
      'autoGainControl': true,
    }.jsify()!;
    _mic = await web.window.navigator.mediaDevices
        .getUserMedia(web.MediaStreamConstraints(audio: constraints))
        .toDart;
    _audio = web.AudioContext();
    _myMeter = _meterFor(_mic!);
    _micOn = true;
  }

  @override
  Future<void> stop() async {
    for (final id in _calls.keys.toList()) {
      disconnect(id);
    }
    final mic = _mic;
    _mic = null;
    if (mic != null) {
      for (final track in mic.getTracks().toDart) {
        track.stop();
      }
    }
    _myMeter = null;
    await _audio?.close().toDart;
    _audio = null;
  }

  @override
  void setMic(bool on) {
    _micOn = on;
    final mic = _mic;
    if (mic == null) return;
    for (final track in mic.getAudioTracks().toDart) {
      track.enabled = on;
    }
  }

  web.RTCPeerConnection _newConnection(String peerId) {
    final pc = web.RTCPeerConnection(
      web.RTCConfiguration(
        iceServers: [
          web.RTCIceServer(
            urls: [for (final url in _stunServers) url.toJS].toJS,
          ),
        ].toJS,
      ),
    );
    final call = _Call(pc);
    _calls[peerId] = call;

    final mic = _mic;
    if (mic != null) {
      for (final track in mic.getAudioTracks().toDart) {
        pc.addTrack(track, mic);
      }
    }
    pc.onicecandidate = ((web.RTCPeerConnectionIceEvent event) {
      final candidate = event.candidate;
      if (candidate == null) return;
      final init = candidate.toJSON();
      _send(peerId, {
        'kind': 'ice',
        'candidate': init.candidate,
        'sdpMid': init.sdpMid,
        'sdpMLineIndex': init.sdpMLineIndex,
      });
    }).toJS;
    pc.ontrack = ((web.RTCTrackEvent event) {
      final streams = event.streams.toDart;
      final stream = streams.isNotEmpty
          ? streams.first
          : (web.MediaStream()..addTrack(event.track));
      final audio = call.audio ?? web.HTMLAudioElement()
        ..autoplay = true;
      audio.srcObject = stream;
      audio.volume = call.volume;
      call.audio = audio;
      call.meter = _meterFor(stream);
      audio.play().toDart.catchError((Object _) => null);
    }).toJS;
    pc.onconnectionstatechange = ((web.Event _) {
      final state = pc.connectionState;
      if (state == 'failed' || state == 'closed') {
        debugPrint('Voice: call with $peerId $state');
        disconnect(peerId);
      }
    }).toJS;
    return pc;
  }

  @override
  Future<void> connect(String peerId, {required bool initiator}) async {
    if (_calls.containsKey(peerId) || _mic == null) return;
    final pc = _newConnection(peerId);
    if (!initiator) {
      // The other side starts; let them know we're ready for an offer.
      _send(peerId, {'kind': 'ready'});
      return;
    }
    // With no description given, the browser creates the offer itself.
    await pc.setLocalDescription().toDart;
    final offer = pc.localDescription;
    if (offer == null) return;
    _send(peerId, {'kind': 'offer', 'sdp': offer.sdp});
  }

  @override
  void disconnect(String peerId) {
    final call = _calls.remove(peerId);
    if (call == null) return;
    call.pc.close();
    call.audio
      ?..pause()
      ..srcObject = null;
  }

  @override
  Future<void> handleSignal(String fromId, Map<String, dynamic> signal) async {
    if (_mic == null) return;
    switch (signal['kind']) {
      case 'ready':
        // They answered our hello; (re)start the call from our side.
        if (!_calls.containsKey(fromId)) {
          await connect(fromId, initiator: true);
        }
      case 'offer':
        final pc = _calls[fromId]?.pc ?? _newConnection(fromId);
        await pc
            .setRemoteDescription(
              web.RTCSessionDescriptionInit(
                type: 'offer',
                sdp: signal['sdp'] as String,
              ),
            )
            .toDart;
        await _flushEarly(fromId);
        // After an offer, the browser creates the answer itself.
        await pc.setLocalDescription().toDart;
        final answer = pc.localDescription;
        if (answer == null) return;
        _send(fromId, {'kind': 'answer', 'sdp': answer.sdp});
      case 'answer':
        final call = _calls[fromId];
        if (call == null) return;
        await call.pc
            .setRemoteDescription(
              web.RTCSessionDescriptionInit(
                type: 'answer',
                sdp: signal['sdp'] as String,
              ),
            )
            .toDart;
        await _flushEarly(fromId);
      case 'ice':
        final call = _calls[fromId];
        if (call == null) return;
        final init = web.RTCIceCandidateInit(
          candidate: signal['candidate'] as String? ?? '',
          sdpMid: signal['sdpMid'] as String?,
          sdpMLineIndex: (signal['sdpMLineIndex'] as num?)?.toInt(),
        );
        if (call.remoteSet) {
          await call.pc.addIceCandidate(init).toDart;
        } else {
          call.early.add(init);
        }
      case 'bye':
        disconnect(fromId);
    }
  }

  Future<void> _flushEarly(String peerId) async {
    final call = _calls[peerId];
    if (call == null) return;
    call.remoteSet = true;
    for (final init in call.early) {
      await call.pc.addIceCandidate(init).toDart;
    }
    call.early.clear();
  }

  @override
  void setVolume(String peerId, double volume) {
    final call = _calls[peerId];
    if (call == null) return;
    call.volume = volume.clamp(0.0, 1.0);
    call.audio?.volume = call.volume;
  }

  web.AnalyserNode? _meterFor(web.MediaStream stream) {
    final audio = _audio;
    if (audio == null) return null;
    final analyser = audio.createAnalyser()..fftSize = 512;
    audio.createMediaStreamSource(stream).connect(analyser);
    return analyser;
  }

  /// Loudness 0..1 from a level meter.
  static double _level(web.AnalyserNode? meter) {
    if (meter == null) return 0;
    final data = Uint8List(meter.fftSize);
    meter.getByteTimeDomainData(data.toJS);
    var sum = 0.0;
    for (final v in data) {
      final x = (v - 128) / 128;
      sum += x * x;
    }
    return math.sqrt(sum / data.length);
  }

  static const double _talkingLevel = 0.04;

  @override
  Set<String> speakers({required String me}) => {
    if (_micOn && _level(_myMeter) > _talkingLevel) me,
    for (final entry in _calls.entries)
      if (entry.value.volume > 0.02 &&
          _level(entry.value.meter) > _talkingLevel)
        entry.key,
  };
}
