import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

import 'notification_preferences.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  // ---------------------------------------------------------------
  // Channel ids
  // ---------------------------------------------------------------

  static const String _messagesChannelId = 'webs_messages_v2';
  static const String _messagesChannelName = 'Messages';
  static const String _messagesChannelDescription =
      'Notifications for new Webs messages.';

  static const String _callsChannelId = 'webs_calls_v2';
  static const String _callsChannelName = 'Calls';
  static const String _callsChannelDescription =
      'Incoming call notifications for Webs.';

  static const String _locationsChannelId = 'webs_locations';
  static const String _locationsChannelName = 'Location requests';
  static const String _locationsChannelDescription =
      'Notifications for incoming location requests.';

  static final Int64List _messageVibrationPattern =
      Int64List.fromList(<int>[0, 300, 200, 300]);

  static final Int64List _callVibrationPattern =
      Int64List.fromList(<int>[0, 1000, 500, 1000, 500, 1000]);

  static const List<int> _callVibrationMilliseconds =
      <int>[0, 1000, 500, 1000, 500, 1000];



  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  final StreamController<String> _taps =
      StreamController<String>.broadcast();

  final StreamController<String> _callTaps =
      StreamController<String>.broadcast();

  final StreamController<String> _locationTaps =
      StreamController<String>.broadcast();

  Stream<String> get notificationTaps => _taps.stream;

  Stream<String> get callTaps => _callTaps.stream;

  /// Emits the conversationId when the user taps a location
  /// request notification.
  Stream<String> get locationTaps => _locationTaps.stream;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (!NotificationPreferences.instance.loadedOnce) {
      await NotificationPreferences.instance.load();
    }

    const androidInit = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initSettings = InitializationSettings(
      android: androidInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundNotificationTap,
    );

    await _createChannels();
    await _requestPermissions();
  }

  Future<void> _createChannels() async {
    if (!Platform.isAndroid) return;

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        _messagesChannelId,
        _messagesChannelName,
        description: _messagesChannelDescription,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: const Color(0xFF25D366),
        vibrationPattern: _messageVibrationPattern,
      ),
    );

    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        _callsChannelId,
        _callsChannelName,
        description: _callsChannelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: const Color(0xFF25D366),
        vibrationPattern: _callVibrationPattern,
      ),
    );

    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        _locationsChannelId,
        _locationsChannelName,
        description: _locationsChannelDescription,
        importance: Importance.high,
        playSound: true,
        enableVibration: false,
        enableLights: true,
        ledColor: const Color(0xFF25D366),
      ),
    );
  }

  /// Asks the OS for notification permission.
  ///
  /// Android 13+ and iOS require explicit permission before
  /// anything will appear. If this isn't called, `_plugin.show`
  /// silently fails.
  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        debugPrint('NOTIF: android permission granted = $granted');
      }
    }
    // iOS: uncomment if you build for iOS
    // else if (Platform.isIOS) {
    //   final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
    //       IOSFlutterLocalNotificationsPlugin>();
    //   await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);
    // }
  }

  bool _isEnabled() {
    return NotificationPreferences.instance.cachedEnabled;
  }

  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> _vibrateForIncomingCall() async {
    try {
      final hasVibrator = await Vibration.hasVibrator() ?? false;
      if (!hasVibrator) {
        debugPrint('NOTIF: device has no vibrator');
        return;
      }
      Vibration.vibrate(pattern: _callVibrationMilliseconds, repeat: 0);
      debugPrint('NOTIF: vibration triggered');
    } catch (e) {
      debugPrint('NOTIF: vibration failed: $e');
    }
  }

  Future<void> _stopVibration() async {
    try {
      Vibration.cancel();
    } catch (_) {}
  }

  // ===================================================================
  // MESSAGE NOTIFICATIONS
  // ===================================================================

  Future<void> showMessageNotification({
    required String senderName,
    required String text,
    required String conversationId,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    if (!_isEnabled()) {
      debugPrint('NOTIF: skipped (notifications disabled in settings)');
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      _messagesChannelId,
      _messagesChannelName,
      channelDescription: _messagesChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      vibrationPattern: _messageVibrationPattern,
      playSound: true,
      sound: null,
    );

    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      conversationId.hashCode,
      senderName,
      text,
      details,
      payload: conversationId,
    );
  }

  // ===================================================================
  // INCOMING CALL NOTIFICATIONS
  // ===================================================================

  Future<void> showIncomingCallNotification({
    required String callId,
    required int callerId,
    required String callerName,
    required String callerPhone,
    required String callType,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    if (!_isEnabled()) {
      debugPrint('NOTIF: call skipped (notifications disabled in settings)');
      return;
    }

    await _vibrateForIncomingCall();

    final androidDetails = AndroidNotificationDetails(
      _callsChannelId,
      _callsChannelName,
      channelDescription: _callsChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      vibrationPattern: _callVibrationPattern,
      playSound: true,
      sound: null,
    );

    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      callId.hashCode,
      'Incoming $callType call',
      '$callerName is calling you',
      details,
      payload: 'call:$callId:$callerId:$callerName:$callerPhone',
    );
  }

  Future<void> dismissIncomingCallNotification(String callId) async {
    await _plugin.cancel(callId.hashCode);
    await _stopVibration();
  }

  // ===================================================================
  // LOCATION REQUEST NOTIFICATIONS
  // ===================================================================

  Future<void> showLocationRequestNotification({
    required int requestId,
    required int requesterId,
    required String requesterName,
    required String conversationId,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    if (!_isEnabled()) {
      debugPrint(
        'NOTIF: location skipped (notifications disabled in settings)',
      );
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      _locationsChannelId,
      _locationsChannelName,
      channelDescription: _locationsChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: false,
      sound: null,
    );

    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      requestId.hashCode,
      'Location request',
      '$requesterName wants to see your location',
      details,
      payload: 'location:$requestId:$requesterId:$conversationId',
    );
  }



  // ===================================================================
  // TAP HANDLING
  // ===================================================================

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    if (payload.startsWith('call:')) {
      final stripped = payload.substring(5);
      _callTaps.add(stripped);
      debugPrint('NOTIFICATION TAP (call): $payload');
      return;
    }

    if (payload.startsWith('location:')) {
      final stripped = payload.substring(9);
      _locationTaps.add(stripped);
      debugPrint('NOTIFICATION TAP (location): $payload');
      return;
    }

    _taps.add(payload);
    debugPrint('NOTIFICATION TAP: payload=$payload');
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTap(
    NotificationResponse response,
  ) {
    debugPrint('NOTIFICATION TAP (background): ${response.payload}');
  }
}