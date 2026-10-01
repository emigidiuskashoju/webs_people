import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

import '../../../core/storage/auth_storage.dart';
import '../../../core/storage/saved_account_storage.dart';
import '../incoming_call_screen.dart';
import '../models/call_record.dart';
import 'call_history_service.dart';
import 'call_signaling_service.dart';

/// Polls the backend for incoming calls while the app is alive.
class CallIncomingListener {
  CallIncomingListener._();

  static final CallIncomingListener instance = CallIncomingListener._();

  final CallSignalingService _signaling = CallSignalingService();
  final AuthStorage _authStorage = AuthStorage();
  final SavedAccountStorage _savedAccountStorage = SavedAccountStorage();
  final CallHistoryService _historyService = CallHistoryService();

  GlobalKey<NavigatorState>? _navigatorKey;

  Timer? _pollTimer;
  bool _initialized = false;

  /// Prevents showing two incoming screens at once.
  bool _showingIncoming = false;

  /// Tracks the most recently handled call id so we don't
  /// re-show the same call after it was already answered or
  /// declined.
  String? _lastHandledCallId;

  Future<void> initialize(
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    if (_initialized) return;
    _initialized = true;

    _navigatorKey = navigatorKey;

    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollOnce(),
    );

    // Immediate first poll.
    _pollOnce();

    debugPrint('CALL-LISTENER: started');
  }

  Future<void> _pollOnce() async {
    if (_showingIncoming) return;

    final token = await _authStorage.getToken();
    if (token == null || token.isEmpty) return;

    try {
      final events = await _signaling.getPendingEvents();

      for (final event in events) {
        if (event.event != 'incoming_call') continue;
        if (event.callId == _lastHandledCallId) continue;

        _lastHandledCallId = event.callId;

        final type = event.payload['type']?.toString() ?? 'audio';
        final callerId = event.payload['caller_id'];
        final callerName = event.payload['caller_name']?.toString() ?? '';
        final callerPhone =
            event.payload['caller_phone_number']?.toString() ?? '';

        if (callerId is! int) continue;

        // Acknowledge the event so we don't see it again.
        try {
          await _signaling.acknowledgeEvent(event.id);
        } catch (_) {}

        await _showIncomingCall(
          callId: event.callId,
          callerId: callerId,
          callerName: callerName,
          callerPhone: callerPhone,
          type: type,
        );

        // Only handle one incoming call per poll.
        break;
      }
    } catch (e) {
      debugPrint('CALL-LISTENER: poll failed: $e');
    }
  }

  Future<void> _showIncomingCall({
    required String callId,
    required int callerId,
    required String callerName,
    required String callerPhone,
    required String type,
  }) async {
    _showingIncoming = true;

    // Play the ringtone and vibrate.
    try {
      FlutterRingtonePlayer().playRingtone(
        looping: true,
        asAlarm: false,
      );
    } catch (e) {
      debugPrint('CALL-LISTENER: ringtone failed: $e');
    }

    // Save an incoming call record locally, so it appears in
    // history even if the user misses it.
    CallRecord? record;
    try {
      record = await _historyService.createIncomingCall(
        callId: callId,
        remoteUserId: callerId,
        remoteName: callerName,
        remotePhoneNumber: callerPhone,
        type: type == 'video'
            ? CallType.video
            : CallType.audio,
      );
    } catch (_) {}

    if (record == null) {
      FlutterRingtonePlayer().stop();
      _showingIncoming = false;
      return;
    }

    // Show the incoming call screen.
    try {
      final navigator = _navigatorKey?.currentState;

      if (navigator == null) {
        FlutterRingtonePlayer().stop();
        _showingIncoming = false;
        return;
      }

      await navigator.push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => IncomingCallScreen(
            callId: callId,
            callerId: callerId,
            callerName: callerName,
            callerPhone: callerPhone,
            type: type,
            record: record!,
          ),
        ),
      );
    } catch (e) {
      debugPrint('CALL-LISTENER: navigation failed: $e');
    } finally {
      FlutterRingtonePlayer().stop();
      _showingIncoming = false;
    }
  }

  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }
}