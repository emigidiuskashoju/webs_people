import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../storage/auth_storage.dart';
import 'notification_service.dart';

/// Top-level background message handler.
///
/// When the app is in the background or killed, Android
/// shows the notification block of the FCM payload
/// automatically. This handler runs to build the data
/// for a future tap.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(
  RemoteMessage message,
) async {
  final data = message.data;
  final type = data['type'] as String?;

  debugPrint(
    'FCM (background): message received: '
    '${message.messageId}, type=$type',
  );

  if (type == 'incoming_call') {
    // Android is already showing the notification from the
    // `notification` block. We only need to make sure the
    // NotificationService is initialised so its tap stream
    // is ready when the user taps.
    final notificationService = NotificationService.instance;
    await notificationService.initialize();
  }
}

class FcmService {
  FcmService._();

  static final FcmService instance = FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final ApiClient _apiClient = ApiClient();
  final AuthStorage _authStorage = AuthStorage();

  bool _initialized = false;

  final StreamController<String> _messageTapController =
      StreamController<String>.broadcast();

  Stream<String> get messageTaps => _messageTapController.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(
      _firebaseBackgroundHandler,
    );

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );
    FirebaseMessaging.onMessageOpenedApp.listen(
      _handleNotificationTap,
    );

    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      Future<void>.delayed(
        const Duration(milliseconds: 800),
        () => _handleNotificationTap(initial),
      );
    }

    await _registerCurrentToken();

    _messaging.onTokenRefresh.listen(_onTokenRefreshed);

    debugPrint('FCM: initialised');
  }

  Future<void> registerTokenNow() async {
    await _registerCurrentToken();
  }

  // ===================================================================
  // TOKEN REGISTRATION
  // ===================================================================

  Future<void> _registerCurrentToken() async {
    try {
      final token = await _messaging.getToken();

      if (token == null || token.isEmpty) {
        debugPrint('FCM: no token yet (may not be available)');
        return;
      }

      await _sendTokenToServer(token);
    } catch (e) {
      debugPrint('FCM: failed to get token: $e');
    }
  }

  Future<void> _onTokenRefreshed(String token) async {
    debugPrint('FCM: token refreshed');
    await _sendTokenToServer(token);
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      final authToken = await _authStorage.getToken();

      if (authToken == null || authToken.isEmpty) {
        debugPrint('FCM: no auth token, skipping registration');
        return;
      }

      final platform = Platform.isAndroid ? 'android' : 'ios';

      await _apiClient.post(
        ApiEndpoints.fcmToken,
        token: authToken,
        body: {
          'token': token,
          'platform': platform,
        },
      );

      debugPrint('FCM: token registered with server');
    } catch (e) {
      debugPrint('FCM: failed to register token: $e');
    }
  }

  // ===================================================================
  // FOREGROUND MESSAGE HANDLING
  // ===================================================================

  Future<void> _handleForegroundMessage(
    RemoteMessage message,
  ) async {
    final data = message.data;
    final type = data['type'] as String?;

    if (type == 'incoming_call') {
      final callId = data['call_id'] as String?;
      final callerIdRaw = data['caller_id'];
      final callerName =
          data['caller_name'] as String? ?? '';
      final callerPhone =
          data['caller_phone_number'] as String? ?? '';
      final callType =
          data['call_type'] as String? ?? 'audio';

      if (callId == null || callId.isEmpty) {
        debugPrint('FCM: call push missing call_id');
        return;
      }

      final callerId =
          int.tryParse(callerIdRaw?.toString() ?? '');
      if (callerId == null) {
        debugPrint('FCM: call push missing caller_id');
        return;
      }

      // Cancel whatever Android showed automatically from
      // the notification block, then replace it with our
      // call-specific notification (category: call,
      // fullScreenIntent: true).
      await NotificationService.instance.cancelNotification(
        callId.hashCode,
      );

      await NotificationService.instance
          .showIncomingCallNotification(
        callId: callId,
        callerId: callerId,
        callerName: callerName,
        callerPhone: callerPhone,
        callType: callType,
      );

      debugPrint('FCM: replaced OS notification with call notification');
      return;
    }

    final conversationId =
        data['conversation_id'] as String?;
    final senderName =
        data['sender_name'] as String? ?? 'New message';
    final body = data['body'] as String? ??
        message.notification?.body ??
        '';

    if (conversationId == null ||
        conversationId.isEmpty) {
      debugPrint(
        'FCM: foreground message missing conversation_id',
      );
      return;
    }

    await NotificationService.instance.showMessageNotification(
      senderName: senderName,
      text: body,
      conversationId: conversationId,
    );

    debugPrint('FCM: showed foreground notification');
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;

    if (type == 'incoming_call') {
      debugPrint(
        'FCM: incoming call notification tapped — '
        'NotificationService.callTaps will handle it',
      );
      return;
    }

    final conversationId =
        data['conversation_id'] as String?;

    if (conversationId == null ||
        conversationId.isEmpty) {
      debugPrint('FCM: notification tap missing conversation_id');
      return;
    }

    _messageTapController.add(conversationId);

    debugPrint(
      'FCM: notification tapped, '
      'conversation=$conversationId',
    );
  }
}