import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  static const String _tokenKey =
      'webs_auth_token';

  final FlutterSecureStorage _storage;

  AuthStorage({
    FlutterSecureStorage? storage,
  }) : _storage =
            storage ??
            const FlutterSecureStorage();

  Future<void> saveToken(
    String token,
  ) async {
    await _storage.write(
      key: _tokenKey,
      value: token,
    );
  }

  Future<String?> getToken() async {
    return _storage.read(
      key: _tokenKey,
    );
  }

  Future<bool> hasToken() async {
    final token = await getToken();

    return token != null &&
        token.isNotEmpty;
  }

  Future<void> clearToken() async {
    await _storage.delete(
      key: _tokenKey,
    );
  }
}