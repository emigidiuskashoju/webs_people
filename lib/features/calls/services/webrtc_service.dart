import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRtcService {
  RTCPeerConnection? _peerConnection;

  MediaStream? _localStream;

  final List<RTCIceCandidate>
      _pendingCandidates = [];

  final Map<String, dynamic>
      _configuration = {
    'iceServers': [
      {
        'urls': [
          'stun:stun.l.google.com:19302',
        ],
      },
    ],
  };

  Future<void> initialize() async {
    if (_peerConnection != null) {
      return;
    }

    _peerConnection =
        await createPeerConnection(
      _configuration,
      {
        'mandatory': {},
        'optional': [],
      },
    );

    _peerConnection!
        .onIceCandidate = (candidate) {
      onIceCandidate?.call(
        candidate,
      );
    };

    _peerConnection!
        .onConnectionState =
        (state) {
      onConnectionStateChanged
          ?.call(state);
    };

    _peerConnection!
        .onIceConnectionState =
        (state) {
      onIceConnectionStateChanged
          ?.call(state);
    };

    _peerConnection!
        .onTrack = (event) {
      if (event.streams.isNotEmpty) {
        onRemoteStream?.call(
          event.streams.first,
        );
      }
    };
  }

  Future<void> startMicrophone() async {
    await initialize();

    if (_localStream != null) {
      return;
    }

    _localStream =
        await navigator.mediaDevices
            .getUserMedia({
      'audio': true,
      'video': false,
    });

    for (final track
        in _localStream!.getAudioTracks()) {
      await _peerConnection!
          .addTrack(
        track,
        _localStream!,
      );
    }
  }

  Future<RTCSessionDescription>
      createOffer() async {
    await startMicrophone();

    final offer =
        await _peerConnection!
            .createOffer({
      'offerToReceiveAudio':
          true,
      'offerToReceiveVideo':
          false,
    });

    await _peerConnection!
        .setLocalDescription(
      offer,
    );

    return offer;
  }

  Future<RTCSessionDescription>
      createAnswer() async {
    await startMicrophone();

    final answer =
        await _peerConnection!
            .createAnswer({
      'offerToReceiveAudio':
          true,
      'offerToReceiveVideo':
          false,
    });

    await _peerConnection!
        .setLocalDescription(
      answer,
    );

    return answer;
  }

  Future<void>
      setRemoteOffer({
    required String sdp,
    required String type,
  }) async {
    await initialize();

    await startMicrophone();

    await _peerConnection!
        .setRemoteDescription(
      RTCSessionDescription(
        sdp,
        type,
      ),
    );
  }

  Future<void>
      setRemoteAnswer({
    required String sdp,
    required String type,
  }) async {
    await initialize();

    await _peerConnection!
        .setRemoteDescription(
      RTCSessionDescription(
        sdp,
        type,
      ),
    );
  }

  Future<void> addIceCandidate(
    RTCIceCandidate candidate,
  ) async {
    if (_peerConnection == null) {
      _pendingCandidates
          .add(candidate);

      return;
    }

    final remoteDescription =
        await _peerConnection!
            .getRemoteDescription();

    if (remoteDescription == null) {
      _pendingCandidates
          .add(candidate);

      return;
    }

    await _peerConnection!
        .addCandidate(
      candidate,
    );
  }

  Future<void>
      flushPendingCandidates() async {
    if (_peerConnection == null) {
      return;
    }

    final remoteDescription =
        await _peerConnection!
            .getRemoteDescription();

    if (remoteDescription == null) {
      return;
    }

    final candidates =
        List<RTCIceCandidate>.from(
      _pendingCandidates,
    );

    _pendingCandidates.clear();

    for (final candidate
        in candidates) {
      await _peerConnection!
          .addCandidate(
        candidate,
      );
    }
  }

  Future<void> setMicrophoneEnabled(
    bool enabled,
  ) async {
    final stream =
        _localStream;

    if (stream == null) {
      return;
    }

    for (final track
        in stream.getAudioTracks()) {
      track.enabled = enabled;
    }
  }

  Future<void> close() async {
    final localStream =
        _localStream;

    if (localStream != null) {
      for (final track
          in localStream.getTracks()) {
        track.stop();
      }

      await localStream.dispose();

      _localStream = null;
    }

    final connection =
        _peerConnection;

    if (connection != null) {
      await connection.close();
      await connection.dispose();

      _peerConnection = null;
    }

    _pendingCandidates.clear();
  }

  Function(RTCIceCandidate)?
      onIceCandidate;

  Function(MediaStream)?
      onRemoteStream;

  Function(
    RTCPeerConnectionState,
  )?
      onConnectionStateChanged;

  Function(
    RTCIceConnectionState,
  )?
      onIceConnectionStateChanged;

  RTCPeerConnection?
      get peerConnection =>
          _peerConnection;

  MediaStream?
      get localStream =>
          _localStream;
}