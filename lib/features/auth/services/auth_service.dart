import 'package:flutter/foundation.dart';

import '../../../core/background/background_location_service.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/notifications/fcm_service.dart';
import '../../../core/storage/auth_storage.dart';
import '../../../core/storage/saved_account_storage.dart';
import '../../devices/services/device_service.dart';
import '../../location/services/location_tracking_service.dart';

class AuthService {
  final ApiClient _apiClient;
  final AuthStorage _storage;
  final SavedAccountStorage _savedAccountStorage;

  AuthService({
    ApiClient? apiClient,
    AuthStorage? storage,
    SavedAccountStorage? savedAccountStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _storage = storage ?? AuthStorage(),
        _savedAccountStorage =
            savedAccountStorage ?? SavedAccountStorage();

  // ============================================================
  // SESSION STATE CLEANUP
  // ============================================================

  Future<void> _clearLocalSessionState() async {
    try {
      await LocationTrackingService().stop();
    } catch (e) {
      debugPrint('AUTH: tracking stop failed: $e');
    }

    // Stop the native background service. This removes the
    // persistent notification and stops all uploads.
    try {
      await BackgroundLocationService.instance.stop();
    } catch (e) {
      debugPrint('AUTH: background service stop failed: $e');
    }
  }

  // ------------------------------------------------------------
  // PIN VALIDATION
  // ------------------------------------------------------------

  bool _isValidPin(String pin) {
    return RegExp(r'^\d{4}$').hasMatch(pin);
  }

  // ------------------------------------------------------------
  // REGISTER
  // ------------------------------------------------------------

  Future<String> register({
    required String name,
    required String email,
    required String phoneNumber,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.register,
      body: {
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'phone_number': phoneNumber.trim(),
      },
    );

    if (response is! Map<String, dynamic>) {
      throw const ApiException('Invalid registration response.');
    }

    final responseEmail = response['email'];

    if (responseEmail is String &&
        responseEmail.trim().isNotEmpty) {
      return responseEmail.trim().toLowerCase();
    }

    return email.trim().toLowerCase();
  }

  // ------------------------------------------------------------
  // VERIFY EMAIL
  // ------------------------------------------------------------

  Future<bool> verifyEmail({
    required String email,
    required String code,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.verifyEmail,
      body: {
        'email': email.trim().toLowerCase(),
        'code': code.trim(),
      },
    );

    if (response is! Map<String, dynamic>) {
      throw const ApiException('Invalid email verification response.');
    }

    final verified = response['verified'];

    if (verified == true) return true;

    final message = response['message'];

    if (message is String && message.trim().isNotEmpty) {
      throw ApiException(message.trim());
    }

    throw const ApiException('Email verification was not completed.');
  }

  // ------------------------------------------------------------
  // SET PASSWORD (4-digit PIN)
  // ------------------------------------------------------------

  Future<Map<String, dynamic>> setPassword({
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    if (!_isValidPin(password)) {
      throw const ApiException('PIN must be exactly 4 digits.');
    }
    if (password != passwordConfirmation) {
      throw const ApiException('PINs do not match.');
    }

    final response = await _apiClient.post(
      ApiEndpoints.setPassword,
      body: {
        'email': email.trim().toLowerCase(),
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );

    if (response is! Map<String, dynamic>) {
      throw const ApiException('Invalid password setup response.');
    }

    final token = response['token'];

    if (token is! String || token.isEmpty) {
      throw const ApiException(
        'The server did not return an authentication token.',
      );
    }

    await _storage.saveToken(token);

    try {
      await FcmService.instance.registerTokenNow();
    } catch (_) {}

    final user = response['user'];

    if (user is! Map<String, dynamic>) {
      throw const ApiException(
        'Invalid account data returned by the server.',
      );
    }

    final userId = user['id'];

    if (userId is! int) {
      throw const ApiException(
        'Invalid user ID returned by the server.',
      );
    }

    await _savedAccountStorage.saveAccount(
      SavedAccount(
        userId: userId,
        name: user['name']?.toString() ?? '',
        email: user['email']?.toString() ?? email.trim().toLowerCase(),
        phoneNumber: user['phone_number']?.toString() ?? '',
        token: token,
      ),
    );

    return user;
  }

  // ------------------------------------------------------------
  // LOGIN (email + 4-digit PIN)
  // ------------------------------------------------------------

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    if (!_isValidPin(password)) {
      throw const ApiException('PIN must be exactly 4 digits.');
    }

    final response = await _apiClient.post(
      ApiEndpoints.login,
      body: {
        'email': email.trim().toLowerCase(),
        'password': password,
      },
    );

    if (response is! Map<String, dynamic>) {
      throw const ApiException('Invalid login response.');
    }

    final token = response['token'];

    if (token is! String || token.isEmpty) {
      throw const ApiException(
        'The server did not return an authentication token.',
      );
    }

    await _storage.saveToken(token);

    try {
      await FcmService.instance.registerTokenNow();
    } catch (_) {}

    try {
      await DeviceService().registerDevice();
    } catch (e) {
      debugPrint('AUTH: device register after login failed: $e');
    }

    final user = response['user'];

    if (user is! Map<String, dynamic>) {
      throw const ApiException(
        'Invalid user data returned by the server.',
      );
    }

    return user;
  }

  // ------------------------------------------------------------
  // SWITCH ACCOUNT
  // ------------------------------------------------------------

  Future<void> switchAccount(String newToken) async {
    await _clearLocalSessionState();
    await _storage.saveToken(newToken);

    try {
      await DeviceService().registerDevice();
    } catch (e) {
      debugPrint('AUTH: device register after switch failed: $e');
    }

    try {
      await FcmService.instance.registerTokenNow();
    } catch (_) {}
  }

  // ------------------------------------------------------------
  // RESEND VERIFICATION CODE
  // ------------------------------------------------------------

  Future<void> resendVerificationCode({
    required String email,
  }) async {
    await _apiClient.post(
      ApiEndpoints.resendVerificationCode,
      body: {'email': email.trim().toLowerCase()},
    );
  }

  // ------------------------------------------------------------
  // CURRENT USER
  // ------------------------------------------------------------

  Future<Map<String, dynamic>> me() async {
    final token = await _storage.getToken();

    if (token == null || token.isEmpty) {
      throw const ApiException('No authentication token was found.');
    }

    final response = await _apiClient.get(
      ApiEndpoints.me,
      token: token,
    );

    if (response is! Map<String, dynamic>) {
      throw const ApiException('Invalid user response.');
    }

    final user = response['user'];

    if (user is! Map<String, dynamic>) {
      throw const ApiException('Invalid user data.');
    }

    return user;
  }

  // ------------------------------------------------------------
  // STORED TOKEN
  // ------------------------------------------------------------

  Future<String?> getStoredToken() async {
    return _storage.getToken();
  }

  // ------------------------------------------------------------
  // LOGOUT
  // ------------------------------------------------------------

  Future<void> logout() async {
    final token = await _storage.getToken();

    if (token != null && token.isNotEmpty) {
      try {
        await _apiClient.post(
          ApiEndpoints.logout,
          token: token,
        );
      } finally {
        await _clearLocalSessionState();
        await _storage.clearToken();
      }
    } else {
      await _clearLocalSessionState();
      await _storage.clearToken();
    }
  }
}