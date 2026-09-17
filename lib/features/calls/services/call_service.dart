import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../data/call_repository.dart';
import '../models/call_record.dart';
import 'call_signaling_service.dart';
import 'webrtc_service.dart';

class CallService {
  final CallRepository _repository;
  final CallSignalingService _signaling;
  final WebRtcService _webRtc;

  Timer? _pollTimer;

  String? _activeCallId;
  int? _remoteUserId;

  CallRecord? _activeRecord;

  final ValueNotifier<CallStatus> callStatus =
      ValueNotifier<CallStatus>(
    CallStatus.calling,
  );

  String? callError;

  CallService({
    CallRepository? repository,
    CallSignalingService? signaling,
    WebRtcService? webRtc,
  })  : _repository =
            repository ?? CallRepository(),
        _signaling =
            signaling ?? CallSignalingService(),
        _webRtc =
            webRtc ?? WebRtcService();

  Future<CallRecord> startAudioCall({
    required int ownerUserId,
    required int recipientId,
    required String recipientName,
    required String recipientPhoneNumber,
  }) async {
    _remoteUserId = recipientId;

    callError = null;

    callStatus.value =
        CallStatus.calling;

    try {
      final start =
          await _signaling.startCall(
        recipientId: recipientId,
        type: 'audio',
      );

      final record =
          await _repository.createOutgoingCall(
        ownerUserId: ownerUserId,
        callId: start.callId,
        remoteUserId: recipientId,
        remoteName: recipientName,
        remotePhoneNumber:
            recipientPhoneNumber,
        type: CallType.audio,
      );

      _activeCallId = start.callId;
      _activeRecord = record;

      _webRtc.onIceCandidate =
          _sendIceCandidate;

      _webRtc.onConnectionStateChanged =
          _handleConnectionState;

      _webRtc.onIceConnectionStateChanged =
          _handleIceConnectionState;

      await _webRtc.initialize();

      final offer =
          await _webRtc.createOffer();

      await _signaling.sendEvent(
        callId: start.callId,
        recipientId: recipientId,
        event: 'offer',
        payload: {
          'sdp': offer.sdp ?? '',
          'type': offer.type ?? 'offer',
        },
      );

      _startPolling();

      return record;
    } catch (e) {
      callStatus.value =
          CallStatus.failed;

      callError =
          e.toString();

      await _webRtc.close();

      _activeCallId = null;
      _remoteUserId = null;
      _activeRecord = null;

      rethrow;
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();

    _pollTimer = Timer.periodic(
      const Duration(
        milliseconds: 800,
      ),
      (_) async {
        try {
          await _processActiveCallEvents();
        } catch (_) {
          // Polling failure must not crash
          // the call screen.
        }
      },
    );
  }

  Future<void>
      _processActiveCallEvents() async {
    final callId =
        _activeCallId;

    if (callId == null) {
      return;
    }

    final events =
        await _signaling.getCallEvents(
      callId,
    );

    for (final event in events) {
      await _processEvent(event);

      try {
        await _signaling.acknowledgeEvent(
          event.id,
        );
      } catch (_) {
        // The event may be retrieved again.
      }
    }
  }

  Future<void> _processEvent(
    CallEvent event,
  ) async {
    switch (event.event) {
      case 'accept':
        await _handleAccept(event);
        break;

      case 'decline':
        await _handleDecline(event);
        break;

      case 'end':
        await _handleRemoteEnd(event);
        break;

      case 'answer':
        await _handleAnswer(event);
        break;

      case 'ice':
        await _handleIce(event);
        break;
    }
  }

  Future<void> _handleAccept(
    CallEvent event,
  ) async {
    final record =
        _activeRecord;

    if (record == null) {
      return;
    }

    callStatus.value =
        CallStatus.connecting;

    await _repository.updateStatus(
      localId: record.localId,
      status: CallStatus.connecting,
    );
  }

  Future<void> _handleDecline(
    CallEvent event,
  ) async {
    final record =
        _activeRecord;

    if (record == null) {
      return;
    }

    callStatus.value =
        CallStatus.declined;

    await _repository.markDeclined(
      record.localId,
    );

    await stop(
      preserveStatus: true,
    );
  }

  Future<void> _handleRemoteEnd(
    CallEvent event,
  ) async {
    final record =
        _activeRecord;

    if (record == null) {
      return;
    }

    callStatus.value =
        CallStatus.ended;

    await _repository.markEnded(
      record.localId,
    );

    await stop(
      preserveStatus: true,
    );
  }

  Future<void> _handleAnswer(
    CallEvent event,
  ) async {
    final sdp =
        event.payload['sdp']
            ?.toString();

    final type =
        event.payload['type']
            ?.toString();

    if (sdp == null ||
        sdp.isEmpty ||
        type == null ||
        type.isEmpty) {
      return;
    }

    await _webRtc.setRemoteAnswer(
      sdp: sdp,
      type: type,
    );

    await _webRtc.flushPendingCandidates();

    final record =
        _activeRecord;

    if (record != null) {
      await _repository.markConnected(
        record.localId,
      );
    }

    callStatus.value =
        CallStatus.connected;
  }

  Future<void> _handleIce(
    CallEvent event,
  ) async {
    final candidate =
        event.payload['candidate']
            ?.toString();

    final sdpMid =
        event.payload['sdp_mid']
            ?.toString();

    final rawMLineIndex =
        event.payload['sdp_m_line_index'];

    if (candidate == null ||
        candidate.isEmpty) {
      return;
    }

    int? sdpMLineIndex;

    if (rawMLineIndex is int) {
      sdpMLineIndex =
          rawMLineIndex;
    }

    await _webRtc.addIceCandidate(
      RTCIceCandidate(
        candidate,
        sdpMid,
        sdpMLineIndex,
      ),
    );
  }

  Future<void> _sendIceCandidate(
    RTCIceCandidate candidate,
  ) async {
    final callId =
        _activeCallId;

    final remoteUserId =
        _remoteUserId;

    if (callId == null ||
        remoteUserId == null) {
      return;
    }

    try {
      await _signaling.sendEvent(
        callId: callId,
        recipientId: remoteUserId,
        event: 'ice',
        payload: {
          'candidate':
              candidate.candidate ?? '',
          'sdp_mid':
              candidate.sdpMid,
          'sdp_m_line_index':
              candidate.sdpMLineIndex,
        },
      );
    } catch (_) {
      // ICE delivery is retried through
      // subsequent connection behavior.
    }
  }

  void _handleConnectionState(
    RTCPeerConnectionState state,
  ) {
    switch (state) {
      case RTCPeerConnectionState
            .RTCPeerConnectionStateNew:
        break;

      case RTCPeerConnectionState
            .RTCPeerConnectionStateConnecting:
        callStatus.value =
            CallStatus.connecting;
        break;

      case RTCPeerConnectionState
            .RTCPeerConnectionStateConnected:
        callStatus.value =
            CallStatus.connected;

        final record =
            _activeRecord;

        if (record != null) {
          unawaited(
            _repository.markConnected(
              record.localId,
            ),
          );
        }
        break;

      case RTCPeerConnectionState
            .RTCPeerConnectionStateDisconnected:
        break;

      case RTCPeerConnectionState
            .RTCPeerConnectionStateFailed:
        callStatus.value =
            CallStatus.failed;

        callError =
            'The audio connection failed.';
        break;

      case RTCPeerConnectionState
            .RTCPeerConnectionStateClosed:
        break;
    }
  }

  void _handleIceConnectionState(
    RTCIceConnectionState state,
  ) {
    switch (state) {
      case RTCIceConnectionState
            .RTCIceConnectionStateChecking:
        callStatus.value =
            CallStatus.connecting;
        break;

      case RTCIceConnectionState
            .RTCIceConnectionStateConnected:
      case RTCIceConnectionState
            .RTCIceConnectionStateCompleted:
        callStatus.value =
            CallStatus.connected;
        break;

      case RTCIceConnectionState
            .RTCIceConnectionStateFailed:
        callStatus.value =
            CallStatus.failed;

        callError =
            'The network connection could not be established.';
        break;

      default:
        break;
    }
  }

  Future<void> endCall() async {
    final callId =
        _activeCallId;

    final remoteUserId =
        _remoteUserId;

    final record =
        _activeRecord;

    if (callId != null &&
        remoteUserId != null) {
      try {
        await _signaling.sendEvent(
          callId: callId,
          recipientId: remoteUserId,
          event: 'end',
        );
      } catch (_) {
        // The local call must still end.
      }
    }

    if (record != null) {
      await _repository.markEnded(
        record.localId,
      );
    }

    callStatus.value =
        CallStatus.ended;

    await stop(
      preserveStatus: true,
    );
  }

  Future<void> stop({
    bool preserveStatus = false,
  }) async {
    _pollTimer?.cancel();
    _pollTimer = null;

    await _webRtc.close();

    _activeCallId = null;
    _remoteUserId = null;
    _activeRecord = null;

    if (!preserveStatus) {
      callStatus.value =
          CallStatus.ended;
    }
  }

  CallRecord? get activeRecord =>
      _activeRecord;

  String? get activeCallId =>
      _activeCallId;

  WebRtcService get webRtc =>
      _webRtc;

  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;

    callStatus.dispose();
  }
}