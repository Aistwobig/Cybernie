import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

import 'voice_engine.dart';
import 'voice_engine_stub.dart' as stub;

/// The phone apps' engine (flutter_webrtc). It speaks the same call setup
/// messages as the browser's, so app and web players can talk to each
/// other. Elsewhere (desktop, tests) voice chat stays off.
bool get _native => Platform.isAndroid || Platform.isIOS;

VoiceEngine createVoiceEngine(SignalSender send) =>
    _native ? _NativeVoice(send) : stub.createVoiceEngine(send);

Future<List<DeviceOption>> listMicrophones() => _devices('audioinput');

Future<List<DeviceOption>> listCameras() => _devices('videoinput');

Future<List<DeviceOption>> listSpeakers() => _devices('audiooutput');

bool canChooseSpeaker() => _native;

Future<List<DeviceOption>> _devices(String kind) async {
  if (!_native) return const [];
  final devices = await rtc.navigator.mediaDevices.enumerateDevices();
  return [
    for (final d in devices)
      if (d.kind == kind) DeviceOption(d.deviceId, d.label),
  ];
}

/// Free public servers that help two players find a route to each other.
/// (Strict networks may also need a relay "TURN" server: add it here.)
const List<String> _stunServers = [
  'stun:stun.l.google.com:19302',
  'stun:stun1.l.google.com:19302',
];

/// One call: the connection, their voice, and their camera picture.
class _Call {
  _Call(this.pc);

  final rtc.RTCPeerConnection pc;
  rtc.MediaStreamTrack? voice;

  /// Where our camera goes out in this call (nothing is sent while it's off).
  rtc.RTCRtpSender? videoSender;

  /// Their camera.
  rtc.RTCVideoRenderer? video;

  /// Network candidates that arrived before the offer/answer was set.
  final List<rtc.RTCIceCandidate> early = [];
  bool remoteSet = false;
  double volume = 1;

  /// How loud they are right now, 0 to 1 (from the call's statistics).
  double level = 0;
}

class _NativeVoice implements VoiceEngine {
  _NativeVoice(this._send);

  final SignalSender _send;
  rtc.MediaStream? _mic;
  rtc.MediaStream? _camera;
  rtc.RTCVideoRenderer? _myVideo;
  bool _micOn = true;
  double _myLevel = 0;
  final Map<String, _Call> _calls = {};

  /// Reads everyone's loudness a few times a second (there's no level
  /// meter on the phone, so it comes from the calls' statistics).
  Timer? _meter;

  @override
  bool get supported => true;

  @override
  Set<String> get peers => _calls.keys.toSet();

  /// The chosen microphone (null: the phone's default).
  String? _deviceId;

  Future<rtc.MediaStream> _openMic() =>
      rtc.navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
          if (_deviceId != null && _deviceId!.isNotEmpty) 'deviceId': _deviceId,
        },
        'video': false,
      });

  @override
  Future<void> start() async {
    if (_mic != null) return;
    _mic = await _openMic();
    _micOn = true;
    // Phones play calls on the earpiece by default: use the speaker (or the
    // headphones, if any) unless one was chosen.
    await useSpeaker(_speakerId);
    _meter = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _readLevels(),
    );
  }

  @override
  Future<void> useMic(String? deviceId) async {
    _deviceId = deviceId;
    final old = _mic;
    if (old == null) return; // Used when voice chat starts.
    final fresh = await _openMic();
    final track = fresh.getAudioTracks().first..enabled = _micOn;
    // Swap the microphone in every call without hanging up.
    for (final call in _calls.values) {
      for (final sender in await call.pc.getSenders()) {
        if (sender.track?.kind == 'audio') await sender.replaceTrack(track);
      }
    }
    _mic = fresh;
    for (final t in old.getTracks()) {
      await t.stop();
    }
    await old.dispose();
  }

  /// The chosen speaker for everyone's voices (null: the default one).
  String? _speakerId;

  @override
  Future<void> useSpeaker(String? deviceId) async {
    _speakerId = deviceId;
    if (_mic == null) return; // Used when voice chat starts.
    try {
      if (deviceId == null || deviceId.isEmpty) {
        await rtc.Helper.setSpeakerphoneOnButPreferBluetooth();
      } else {
        await rtc.Helper.selectAudioOutput(deviceId);
      }
    } catch (error) {
      debugPrint('Voice: speaker $error');
    }
  }

  /// The chosen camera (null: the front one).
  String? _cameraId;

  Future<rtc.MediaStream> _openCamera() =>
      rtc.navigator.mediaDevices.getUserMedia({
        'audio': false,
        // Small and at 15 frames a second: everyone sends to everyone nearby
        // directly, so this keeps it light.
        'video': {
          'width': 320,
          'height': 240,
          'frameRate': 15,
          if (_cameraId != null && _cameraId!.isNotEmpty)
            'deviceId': _cameraId
          else
            'facingMode': 'user',
        },
      });

  @override
  Future<void> useCamera(String? deviceId) async {
    _cameraId = deviceId;
    final old = _camera;
    if (old == null) return; // Used when the camera is turned on.
    final fresh = await _openCamera();
    // Swap the camera in every call without calling again.
    _camera = fresh;
    for (final call in _calls.values) {
      await _sendCamera(call);
    }
    _myVideo?.srcObject = fresh;
    for (final t in old.getTracks()) {
      await t.stop();
    }
    await old.dispose();
  }

  @override
  Future<void> setCamera(bool on) async {
    if (on) {
      if (_camera != null) return;
      final camera = await _openCamera();
      _camera = camera;
      _myVideo = await _renderer(camera);
    } else {
      final camera = _camera;
      _camera = null;
      await _myVideo?.dispose();
      _myVideo = null;
      if (camera != null) {
        for (final track in camera.getTracks()) {
          await track.stop();
        }
        await camera.dispose();
      }
    }
    for (final call in _calls.values) {
      await _sendCamera(call);
    }
  }

  /// Puts our camera (or nothing, while it's off) into [call]'s video.
  Future<void> _sendCamera(_Call call) async {
    final sender = call.videoSender;
    if (sender == null) return;
    final tracks = _camera?.getVideoTracks() ?? const [];
    await sender.replaceTrack(tracks.isEmpty ? null : tracks.first);
  }

  static Future<rtc.RTCVideoRenderer> _renderer(rtc.MediaStream stream) async {
    final renderer = rtc.RTCVideoRenderer();
    await renderer.initialize();
    renderer.srcObject = stream;
    return renderer;
  }

  rtc.RTCVideoRenderer? _videoOf(String? peerId) =>
      peerId == null ? _myVideo : _calls[peerId]?.video;

  @override
  bool hasVideo(String? peerId) => _videoOf(peerId) != null;

  /// Frames can't be copied out of the phone's video: the tavern shows
  /// [videoView] instead.
  @override
  Future<ui.Image?> grabFrame(String? peerId) async => null;

  @override
  Widget? videoView(String? peerId) {
    final renderer = _videoOf(peerId);
    if (renderer == null) return null;
    return rtc.RTCVideoView(
      renderer,
      objectFit: rtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    );
  }

  @override
  Future<void> stop() async {
    _meter?.cancel();
    _meter = null;
    await setCamera(false);
    for (final id in _calls.keys.toList()) {
      disconnect(id);
    }
    final mic = _mic;
    _mic = null;
    if (mic != null) {
      for (final track in mic.getTracks()) {
        await track.stop();
      }
      await mic.dispose();
    }
    _myLevel = 0;
  }

  @override
  void setMic(bool on) {
    _micOn = on;
    final mic = _mic;
    if (mic == null) return;
    for (final track in mic.getAudioTracks()) {
      track.enabled = on;
    }
  }

  Future<rtc.RTCPeerConnection> _newConnection(String peerId) async {
    final pc = await rtc.createPeerConnection({
      'iceServers': [
        {'urls': _stunServers},
      ],
      'sdpSemantics': 'unified-plan',
    });
    final call = _Call(pc);
    _calls[peerId] = call;

    final mic = _mic;
    if (mic != null) {
      for (final track in mic.getAudioTracks()) {
        await pc.addTrack(track, mic);
      }
    }
    pc.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      _send(peerId, {
        'kind': 'ice',
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };
    pc.onTrack = (event) async {
      final track = event.track;
      if (track.kind == 'video') {
        // Their camera (it shows only while their camera is on; see
        // VoiceService.watching). A browser sends it without a stream.
        final stream = event.streams.isNotEmpty
            ? event.streams.first
            : (await rtc.createLocalMediaStream('cam-$peerId')
                ..addTrack(track));
        if (!identical(_calls[peerId], call)) return;
        await call.video?.dispose();
        call.video = await _renderer(stream);
        return;
      }
      // Their voice plays by itself; just keep it for its volume.
      call.voice = track;
      _applyVolume(call);
    };
    pc.onConnectionState = (state) {
      if (state == rtc.RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == rtc.RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        debugPrint('Voice: call with $peerId $state');
        disconnect(peerId);
      }
    };
    return pc;
  }

  @override
  Future<void> connect(String peerId, {required bool initiator}) async {
    if (_calls.containsKey(peerId) || _mic == null) return;
    final pc = await _newConnection(peerId);
    if (!initiator) {
      // The other side starts; let them know we're ready for an offer.
      _send(peerId, {'kind': 'ready'});
      return;
    }
    // A video line both ways from the start, so cameras can be switched on
    // and off later without calling again.
    final call = _calls[peerId]!;
    final transceiver = await pc.addTransceiver(
      kind: rtc.RTCRtpMediaType.RTCRtpMediaTypeVideo,
      init: rtc.RTCRtpTransceiverInit(
        direction: rtc.TransceiverDirection.SendRecv,
      ),
    );
    call.videoSender = transceiver.sender;
    await _sendCamera(call);
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    _send(peerId, {'kind': 'offer', 'sdp': offer.sdp});
  }

  @override
  void disconnect(String peerId) {
    final call = _calls.remove(peerId);
    if (call == null) return;
    call.pc.close();
    call.video?.dispose();
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
        final pc = _calls[fromId]?.pc ?? await _newConnection(fromId);
        await pc.setRemoteDescription(
          rtc.RTCSessionDescription(signal['sdp'] as String, 'offer'),
        );
        await _flushEarly(fromId);
        // Send our camera back on their video line.
        final call = _calls[fromId]!;
        for (final t in await pc.getTransceivers()) {
          if (t.receiver.track?.kind == 'video') {
            await t.setDirection(rtc.TransceiverDirection.SendRecv);
            call.videoSender = t.sender;
          }
        }
        await _sendCamera(call);
        final answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);
        _send(fromId, {'kind': 'answer', 'sdp': answer.sdp});
      case 'answer':
        final call = _calls[fromId];
        if (call == null) return;
        await call.pc.setRemoteDescription(
          rtc.RTCSessionDescription(signal['sdp'] as String, 'answer'),
        );
        await _flushEarly(fromId);
      case 'ice':
        final call = _calls[fromId];
        if (call == null) return;
        final candidate = rtc.RTCIceCandidate(
          signal['candidate'] as String? ?? '',
          signal['sdpMid'] as String?,
          (signal['sdpMLineIndex'] as num?)?.toInt(),
        );
        if (call.remoteSet) {
          await call.pc.addCandidate(candidate);
        } else {
          call.early.add(candidate);
        }
      case 'bye':
        disconnect(fromId);
    }
  }

  Future<void> _flushEarly(String peerId) async {
    final call = _calls[peerId];
    if (call == null) return;
    call.remoteSet = true;
    for (final candidate in call.early) {
      await call.pc.addCandidate(candidate);
    }
    call.early.clear();
  }

  @override
  void setVolume(String peerId, double volume) {
    final call = _calls[peerId];
    if (call == null) return;
    final v = volume.clamp(0.0, 1.0);
    // Only when it changes enough to hear: each change is a call to the
    // phone, and this runs a few times a second.
    if ((v - call.volume).abs() < 0.02) return;
    call.volume = v;
    _applyVolume(call);
  }

  void _applyVolume(_Call call) {
    final voice = call.voice;
    if (voice == null) return;
    // On Android, 10 is full volume.
    rtc.Helper.setVolume(call.volume * 10, voice).catchError((Object _) {});
  }

  bool _reading = false;

  Future<void> _readLevels() async {
    if (_reading) return;
    _reading = true;
    try {
      var mine = 0.0;
      for (final call in _calls.values.toList()) {
        var theirs = 0.0;
        for (final report in await call.pc.getStats()) {
          final level = (report.values['audioLevel'] as num?)?.toDouble();
          if (level == null) continue;
          if (report.type == 'inbound-rtp') theirs = level;
          if (report.type == 'media-source') mine = level;
        }
        call.level = theirs;
      }
      _myLevel = mine;
    } catch (_) {
      // A call that just closed: try again next time.
    } finally {
      _reading = false;
    }
  }

  static const double _talkingLevel = 0.03;

  @override
  Set<String> speakers({required String me}) => {
    if (_micOn && _myLevel > _talkingLevel) me,
    for (final entry in _calls.entries)
      if (entry.value.volume > 0.02 && entry.value.level > _talkingLevel)
        entry.key,
  };
}
