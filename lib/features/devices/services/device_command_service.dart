import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/auth_storage.dart';
import 'device_identity_service.dart';

class DeviceCommandService {
  final ApiClient _apiClient;
  final AuthStorage _storage;
  final DeviceIdentityService _identityService;

  DeviceCommandService({
    ApiClient? apiClient,
    AuthStorage? storage,
    DeviceIdentityService? identityService,
  })  : _apiClient = apiClient ?? ApiClient(),
        _storage = storage ?? AuthStorage(),
        _identityService =
            identityService ?? DeviceIdentityService();

  // ============================================================
  // AUTH TOKEN
  // ============================================================
  //
  // The Sanctum login token lives in AuthStorage.
  // It is NOT stored in SecureStorage — SecureStorage is
  // reserved for device identity material.
  //
  // ============================================================

  Future<String> _requireAuthToken() async {
    final token = await _storage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('You must be logged in.');
    }

    return token;
  }

  // ============================================================
  // PENDING COMMANDS
  // ============================================================

  Future<List<Map<String, dynamic>>> getPendingCommands({
    required int deviceId,
  }) async {
    final token = await _requireAuthToken();

    final secret =
        await _identityService.getDeviceSecret();

    final response = await _apiClient.get(
      ApiEndpoints.deviceCommands(deviceId),
      token: token,
      deviceSecret: secret,
    );

    final commands = response['commands'];

    if (commands is! List) {
      return [];
    }

    return commands
        .map(
          (command) =>
              Map<String, dynamic>.from(command),
        )
        .toList();
  }

  // ============================================================
  // CREATE COMMAND
  // ============================================================

  Future<Map<String, dynamic>> createCommand({
    required int deviceId,
    required String command,
    Map<String, dynamic>? payload,
  }) async {
    final token = await _requireAuthToken();

    final response = await _apiClient.post(
      ApiEndpoints.deviceCommands(deviceId),
      token: token,
      body: {
        'command': command,
        'payload': payload ?? {},
      },
    );

    return Map<String, dynamic>.from(
      response['command'] ?? response,
    );
  }

  // ============================================================
  // ACKNOWLEDGE COMMAND
  // ============================================================

  Future<Map<String, dynamic>> acknowledgeCommand({
    required int deviceId,
    required int commandId,
    required String status,
    String? errorMessage,
  }) async {
    final token = await _requireAuthToken();

    final secret =
        await _identityService.getDeviceSecret();

    final response = await _apiClient.post(
      ApiEndpoints.acknowledgeDeviceCommand(
        deviceId,
        commandId,
      ),
      token: token,
      deviceSecret: secret,
      body: {
        'status': status,
        if (errorMessage != null)
          'error_message': errorMessage,
      },
    );

    return Map<String, dynamic>.from(
      response['command'] ?? response,
    );
  }
}