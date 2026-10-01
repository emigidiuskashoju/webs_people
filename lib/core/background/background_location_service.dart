import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class BackgroundLocationService {
  BackgroundLocationService._();
  static final BackgroundLocationService instance =
      BackgroundLocationService._();

  static const String _serviceNotificationChannelId =
      'webs_background_service_channel';
  static const String _serviceNotificationChannelName =
      'Webs Background Service';
  static const String _serviceNotificationChannelDescription =
      'Keeps sharing your location with people you have approved.';

  static const String _prefTokenKey = 'webs_bg_token';
  static const String _prefApiBaseKey = 'webs_bg_api_base';
  static const String _prefRequestIdKey = 'webs_bg_request_id';
  static const String _prefEnabledKey = 'webs_bg_enabled';

  /// Call once during app startup (in main.dart).
  Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // ---------------------------------------------------------------
    // Create the notification channel on the MAIN isolate.
    //
    // flutter_background_service creates a foreground notification
    // using this channel. Without a properly declared channel with
    // IMPORTANCE_LOW (or higher), Android 8+ throws
    // "Bad notification for startForeground" and kills the app.
    // ---------------------------------------------------------------
    if (Platform.isAndroid) {
      final plugin = FlutterLocalNotificationsPlugin();
      const androidInit =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);

      await plugin.initialize(initSettings);

      final androidImpl =
          plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImpl != null) {
        await androidImpl.createNotificationChannel(
          const AndroidNotificationChannel(
            _serviceNotificationChannelId,
            _serviceNotificationChannelName,
            description: _serviceNotificationChannelDescription,
            importance: Importance.low,
            playSound: false,
            enableVibration: false,
            showBadge: false,
          ),
        );
      }
    }

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _serviceNotificationChannelId,
        initialNotificationTitle: 'Webs',
        initialNotificationContent:
            'Sharing your location in the background...',
        foregroundServiceNotificationId: 1001,
        foregroundServiceTypes: [
          AndroidForegroundType.location,
        ],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  Future<void> start({
    required String token,
    required String apiBase,
    required int requestId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefTokenKey, token);
    await prefs.setString(_prefApiBaseKey, apiBase);
    await prefs.setInt(_prefRequestIdKey, requestId);
    await prefs.setBool(_prefEnabledKey, true);

    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
    }
  }

  Future<void> stop() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabledKey, false);

    final service = FlutterBackgroundService();
    service.invoke('stop');
  }
}

// ================================================================
// BACKGROUND SERVICE ENTRY POINT
// ================================================================

@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // -----------------------------------------------------------------
  // Create the notification channel INSIDE the background isolate.
  //
  // Even though we already created it in the main isolate, the
  // background isolate runs in a separate Dart VM and needs the
  // channel to exist before calling setForegroundNotificationInfo()
  // or starting the foreground service.
  // -----------------------------------------------------------------
  if (service is AndroidServiceInstance) {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      const androidInit =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);

      await plugin.initialize(initSettings);

      final androidImpl =
          plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImpl != null) {
        await androidImpl.createNotificationChannel(
          const AndroidNotificationChannel(
            BackgroundLocationService._serviceNotificationChannelId,
            BackgroundLocationService._serviceNotificationChannelName,
            description:
                BackgroundLocationService._serviceNotificationChannelDescription,
            importance: Importance.low,
            playSound: false,
            enableVibration: false,
            showBadge: false,
          ),
        );
      }
    } catch (e) {
      debugPrint('BG-SERVICE: channel setup failed: $e');
    }
  }

  service.on('stop').listen((_) async {
    await service.stopSelf();
  });

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((_) {
    service.stopSelf();
  });

  final prefs = await SharedPreferences.getInstance();

  final token = prefs.getString(
    BackgroundLocationService._prefTokenKey,
  );
  final apiBase = prefs.getString(
    BackgroundLocationService._prefApiBaseKey,
  );
  final requestId = prefs.getInt(
    BackgroundLocationService._prefRequestIdKey,
  );

  if (token == null || apiBase == null || requestId == null) {
    debugPrint('BG-SERVICE: missing credentials, stopping.');
    await service.stopSelf();
    return;
  }

  if (service is AndroidServiceInstance) {
    if (await service.isForegroundService()) {
      service.setForegroundNotificationInfo(
        title: 'Webs',
        content: 'Sharing your location in the background...',
      );
    }
  }

  // Upload every 30 seconds.
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    final enabled = prefs.getBool(
      BackgroundLocationService._prefEnabledKey,
    ) ??
        false;
    if (!enabled) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final url = Uri.parse(
        '$apiBase/location/requests/$requestId/location',
      );

      final response = await http
          .post(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'latitude': position.latitude,
              'longitude': position.longitude,
              'accuracy': position.accuracy,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await prefs.setString(
          'webs_bg_last_upload',
          jsonEncode({
            'latitude': position.latitude,
            'longitude': position.longitude,
            'accuracy': position.accuracy,
            'uploaded_at': DateTime.now().toIso8601String(),
          }),
        );
        debugPrint(
          'BG-SERVICE: uploaded ${position.latitude},${position.longitude}',
        );
      } else {
        debugPrint('BG-SERVICE: server ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('BG-SERVICE: upload failed: $e');
    }
  });
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}