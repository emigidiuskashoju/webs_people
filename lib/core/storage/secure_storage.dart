import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const String _tokenKey = 'webs_auth_token';
  static const String _deviceSecretKey = 'webs_device_secret';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // ============================================================
  // AUTH TOKEN
  // ============================================================

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return _storage.read(key: _tokenKey);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  // ============================================================
  // DEVICE SECRET
  // ============================================================

  Future<void> saveDeviceSecret(String secret) async {
    await _storage.write(key: _deviceSecretKey, value: secret);
  }

  Future<String?> getDeviceSecret() async {
    return _storage.read(key: _deviceSecretKey);
  }

  Future<void> deleteDeviceSecret() async {
    await _storage.delete(key: _deviceSecretKey);
  }

  // ============================================================
  // CLEAR EVERYTHING
  // ============================================================

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);

    await _storage.delete(key: _deviceSecretKey);
  }
}
