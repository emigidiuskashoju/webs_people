import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/auth_storage.dart';

import '../../location/models/device_location.dart';
import '../../location/services/locations_service.dart';

import 'device_identity_service.dart';
import 'device_info_service.dart';

class DeviceService {
  final ApiClient _apiClient;
  final AuthStorage _authStorage;
  final DeviceIdentityService _identityService;
  final DeviceInfoService _infoService;
  final LocationsService _locationService;

  DeviceService({
    ApiClient? apiClient,
    AuthStorage? authStorage,
    DeviceIdentityService? identityService,
    DeviceInfoService? infoService,
    LocationsService? locationService,
  })  : _apiClient = apiClient ?? ApiClient(),
        _authStorage = authStorage ?? AuthStorage(),
        _identityService =
            identityService ?? DeviceIdentityService(),
        _infoService =
            infoService ?? DeviceInfoService(),
        _locationService =
            locationService ?? LocationsService();

  // ============================================================
  // GET AUTHENTICATION TOKEN
  // ============================================================

  Future<String> _requireAuthToken() async {
    final token = await _authStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception(
        'You must be logged in before using device security.',
      );
    }

    return token;
  }

  // ============================================================
  // REGISTER CURRENT PHYSICAL DEVICE
  // ============================================================

  Future<Map<String, dynamic>> registerDevice() async {
    final token = await _requireAuthToken();

    // ------------------------------------------------------------
    // Get or create permanent identity for this physical phone.
    // ------------------------------------------------------------

    final deviceUuid =
        await _identityService.getOrCreateDeviceUuid();

    final deviceSecret =
        await _identityService.getOrCreateDeviceSecret();

    // ------------------------------------------------------------
    // Get phone information.
    // ------------------------------------------------------------

    final deviceInfo =
        await _infoService.getDeviceInfo();

    final deviceName =
        await _infoService.getDefaultDeviceName();

    // ------------------------------------------------------------
    // Register device with Laravel.
    // ------------------------------------------------------------

    final response = await _apiClient.post(
      ApiEndpoints.devices,
      token: token,
      body: {
        'device_uuid': deviceUuid,
        'device_secret': deviceSecret,
        'name': deviceName,
        'platform': deviceInfo['platform'],
        'model': deviceInfo['model'],
        'manufacturer': deviceInfo['manufacturer'],
        'os_version': deviceInfo['os_version'],
        'app_version': deviceInfo['app_version'],
      },
    );

    if (response is! Map<String, dynamic>) {
      throw Exception(
        'Invalid device registration response.',
      );
    }

    final result =
        Map<String, dynamic>.from(response);

    // ------------------------------------------------------------
    // Get the server device ID.
    // ------------------------------------------------------------

    final device = result['device'];

    if (device is Map<String, dynamic>) {
      final deviceId = int.tryParse(
        device['id'].toString(),
      );

      // ----------------------------------------------------------
      // Upload first GPS location.
      //
      // This is optional. Device registration itself must remain
      // successful even when GPS is unavailable.
      // ----------------------------------------------------------

      if (deviceId != null) {
        try {
          await _locationService.captureAndSendLocation(
            deviceId: deviceId,
          );
        } catch (_) {
          // GPS/location failure must NOT cancel
          // successful device registration.
        }
      }
    }

    return result;
  }

  // ============================================================
  // GET MY DEVICES
  // ============================================================

  Future<List<Map<String, dynamic>>> getDevices() async {
    final token = await _requireAuthToken();

    final response = await _apiClient.get(
      ApiEndpoints.devices,
      token: token,
    );

    if (response is! Map<String, dynamic>) {
      return [];
    }

    final devices = response['devices'];

    if (devices is! List) {
      return [];
    }

    return devices
        .whereType<Map>()
        .map(
          (device) =>
              Map<String, dynamic>.from(device),
        )
        .toList();
  }

  // ============================================================
  // HEARTBEAT
  // ============================================================

  Future<Map<String, dynamic>> heartbeat(
    int deviceId,
  ) async {
    final token = await _requireAuthToken();

    final deviceSecret =
        await _identityService.getDeviceSecret();

    final response = await _apiClient.post(
      ApiEndpoints.deviceHeartbeat(deviceId),
      token: token,
      deviceSecret: deviceSecret,
    );

    return Map<String, dynamic>.from(response);
  }

  // ============================================================
  // SEND LOCATION
  // ============================================================

  Future<Map<String, dynamic>> sendLocation({
    required int deviceId,
    required DeviceLocation location,
  }) async {
    final token = await _requireAuthToken();

    final deviceSecret =
        await _identityService.getDeviceSecret();

    final response = await _apiClient.post(
      ApiEndpoints.deviceLocation(deviceId),
      token: token,
      deviceSecret: deviceSecret,
      body: location.toJson(),
    );

    return Map<String, dynamic>.from(response);
  }

  // ============================================================
  // DEVICE LOCATIONS
  // ============================================================

  Future<List<Map<String, dynamic>>> getDeviceLocations(
    int deviceId,
  ) async {
    final token = await _requireAuthToken();

    final response = await _apiClient.get(
      ApiEndpoints.deviceLocations(deviceId),
      token: token,
    );

    if (response is! Map<String, dynamic>) {
      return [];
    }

    final locations = response['locations'];

    if (locations is! List) {
      return [];
    }

    return locations
        .whereType<Map>()
        .map(
          (location) =>
              Map<String, dynamic>.from(location),
        )
        .toList();
  }

  // ============================================================
  // ENABLE LOST MODE
  // ============================================================

  Future<Map<String, dynamic>> enableLostMode(
    int deviceId,
  ) async {
    final token = await _requireAuthToken();

    final response = await _apiClient.post(
      ApiEndpoints.enableLostMode(deviceId),
      token: token,
    );

    return Map<String, dynamic>.from(response);
  }

  // ============================================================
  // DISABLE LOST MODE
  // ============================================================

  Future<Map<String, dynamic>> disableLostMode(
    int deviceId,
  ) async {
    final token = await _requireAuthToken();

    final response = await _apiClient.delete(
      ApiEndpoints.disableLostMode(deviceId),
      token: token,
    );

    return Map<String, dynamic>.from(response);
  }

  // ============================================================
  // RECOVERY DEVICES
  // ============================================================

  Future<List<Map<String, dynamic>>>
      getRecoveryDevices() async {
    final token = await _requireAuthToken();

    final response = await _apiClient.get(
      ApiEndpoints.recovery,
      token: token,
    );

    if (response is! Map<String, dynamic>) {
      return [];
    }

    final devices = response['devices'];

    if (devices is! List) {
      return [];
    }

    return devices
        .whereType<Map>()
        .map(
          (device) =>
              Map<String, dynamic>.from(device),
        )
        .toList();
  }
}