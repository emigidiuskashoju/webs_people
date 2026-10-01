import 'dart:async';
import 'dart:io';

import 'package:geolocator/geolocator.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/auth_storage.dart';

import '../../devices/services/device_identity_service.dart';
import '../models/device_location.dart';

class LocationsService {
  final ApiClient _apiClient;
  final AuthStorage _authStorage;
  final DeviceIdentityService _identityService;

  LocationsService({
    ApiClient? apiClient,
    AuthStorage? authStorage,
    DeviceIdentityService? identityService,
  })  : _apiClient = apiClient ?? ApiClient(),
        _authStorage = authStorage ?? AuthStorage(),
        _identityService =
            identityService ?? DeviceIdentityService();

  // ============================================================
  // LOCATION PERMISSION
  // ============================================================

  Future<bool> ensurePermission() async {
    final serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission =
          await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission ==
            LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  // ============================================================
  // BACKGROUND LOCATION PERMISSION
  // ============================================================

  Future<bool> ensureBackgroundPermission() async {
    final serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission =
          await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission ==
            LocationPermission.deniedForever) {
      return false;
    }

    if (Platform.isAndroid &&
        permission != LocationPermission.always) {
      permission =
          await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission ==
            LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  // ============================================================
  // GET CURRENT GPS LOCATION
  // ============================================================

  Future<DeviceLocation> getCurrentLocation() async {
    final allowed =
        await ensurePermission();

    if (!allowed) {
      throw Exception(
        'Location permission or location services are disabled.',
      );
    }

    final position =
        await Geolocator.getCurrentPosition(
      locationSettings:
          const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    return DeviceLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      altitude: position.altitude,
      speed: position.speed,
      heading: position.heading,
      timestamp:
          position.timestamp ??
          DateTime.now(),
    );
  }

  // ============================================================
  // GET AUTH TOKEN
  // ============================================================

  Future<String> _requireAuthToken() async {
    final token =
        await _authStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception(
        'You must be logged in.',
      );
    }

    return token;
  }

  // ============================================================
  // SEND LOCATION TO LARAVEL
  // ============================================================

  Future<Map<String, dynamic>> sendLocation({
    required int deviceId,
    required DeviceLocation location,
  }) async {
    final token =
        await _requireAuthToken();

    final secret =
        await _identityService.getDeviceSecret();

    final response =
        await _apiClient.post(
      ApiEndpoints.deviceLocation(
        deviceId,
      ),
      token: token,
      deviceSecret: secret,
      body: location.toJson(),
    );

    if (response is! Map<String, dynamic>) {
      throw Exception(
        'Invalid location response from server.',
      );
    }

    return Map<String, dynamic>.from(
      response,
    );
  }

  // ============================================================
  // GET GPS LOCATION AND UPLOAD IT
  // ============================================================

  Future<Map<String, dynamic>>
      captureAndSendLocation({
    required int deviceId,
  }) async {
    final location =
        await getCurrentLocation();

    return sendLocation(
      deviceId: deviceId,
      location: location,
    );
  }

  // ============================================================
  // WATCH DEVICE LOCATION
  // ============================================================

  Stream<Position> watchPosition({
    required bool lostMode,
  }) {
    if (Platform.isAndroid) {
      return Geolocator.getPositionStream(
        locationSettings:
            AndroidSettings(
          accuracy: lostMode
              ? LocationAccuracy.high
              : LocationAccuracy.medium,
          distanceFilter:
              lostMode ? 20 : 50,
          intervalDuration:
              Duration(
            seconds:
                lostMode ? 30 : 300,
          ),
          foregroundNotificationConfig:
              const ForegroundNotificationConfig(
            notificationTitle:
                'Webs Lost Mode',
            notificationText:
                'Webs is monitoring this device location.',
            notificationChannelName:
                'Webs Location Tracking',
            enableWakeLock: true,
            setOngoing: true,
          ),
        ),
      );
    }

    return Geolocator.getPositionStream(
      locationSettings:
          const LocationSettings(
        accuracy:
            LocationAccuracy.high,
        distanceFilter: 50,
      ),
    );
  }
}