import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/secure_storage.dart';

class DeviceIdentityService {
  static const String _deviceUuidKey = 'webs_device_uuid';

  final Uuid _uuid = const Uuid();

  final SecureStorage _secureStorage;

  DeviceIdentityService({SecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? SecureStorage();

  // ============================================================
  // DEVICE UUID
  // ============================================================

  Future<String> getOrCreateDeviceUuid() async {
    final preferences = await SharedPreferences.getInstance();

    final existingUuid = preferences.getString(_deviceUuidKey);

    if (existingUuid != null && existingUuid.isNotEmpty) {
      return existingUuid;
    }

    final newUuid = _uuid.v4();

    await preferences.setString(_deviceUuidKey, newUuid);

    return newUuid;
  }

  Future<String> getDeviceUuid() async {
    final preferences = await SharedPreferences.getInstance();

    final uuid = preferences.getString(_deviceUuidKey);

    if (uuid == null || uuid.isEmpty) {
      throw Exception('Device UUID has not been created yet.');
    }

    return uuid;
  }

  // ============================================================
  // DEVICE SECRET
  // ============================================================

  Future<String> getOrCreateDeviceSecret() async {
    final existingSecret = await _secureStorage.getDeviceSecret();

    if (existingSecret != null && existingSecret.isNotEmpty) {
      return existingSecret;
    }

    final newSecret = _uuid.v4() + _uuid.v4() + _uuid.v4() + _uuid.v4();

    await _secureStorage.saveDeviceSecret(newSecret);

    return newSecret;
  }

  Future<String> getDeviceSecret() async {
    final secret = await _secureStorage.getDeviceSecret();

    if (secret == null || secret.isEmpty) {
      throw Exception('Device secret has not been created yet.');
    }

    return secret;
  }

  // ============================================================
  // IDENTITY STATUS
  // ============================================================

  Future<bool> hasDeviceIdentity() async {
    final preferences = await SharedPreferences.getInstance();

    final uuid = preferences.getString(_deviceUuidKey);

    final secret = await _secureStorage.getDeviceSecret();

    return uuid != null &&
        uuid.isNotEmpty &&
        secret != null &&
        secret.isNotEmpty;
  }

  // ============================================================
  // CLEAR IDENTITY
  // ============================================================

  Future<void> clearIdentity() async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.remove(_deviceUuidKey);

    await _secureStorage.deleteDeviceSecret();
  }
}
