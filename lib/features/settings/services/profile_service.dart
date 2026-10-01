import 'dart:io';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/auth_storage.dart';

class ProfileService {
  final ApiClient _apiClient;
  final AuthStorage _authStorage;

  ProfileService({
    ApiClient? apiClient,
    AuthStorage? authStorage,
  })  : _apiClient =
            apiClient ?? ApiClient(),
        _authStorage =
            authStorage ?? AuthStorage();

  // ============================================================
  // TOKEN
  // ============================================================

  Future<String> _getToken() async {
    final token =
        await _authStorage.getToken();

    if (token == null ||
        token.trim().isEmpty) {
      throw Exception(
        'Your session has expired. Please verify your account again.',
      );
    }

    return token;
  }

  // ============================================================
  // GET PROFILE
  // ============================================================

  Future<Map<String, dynamic>> getProfile() async {
    final token =
        await _getToken();

    final response =
        await _apiClient.get(
      ApiEndpoints.profile,
      token: token,
    );

    if (response is Map<String, dynamic>) {
      final user =
          response['user'];

      if (user is Map) {
        return Map<String, dynamic>.from(
          user,
        );
      }

      return response;
    }

    throw Exception(
      'Invalid profile information returned by the server.',
    );
  }

  // ============================================================
  // UPDATE NAME
  // ============================================================

  Future<Map<String, dynamic>> updateName(
    String name,
  ) async {
    final cleanedName =
        name.trim();

    if (cleanedName.isEmpty) {
      throw Exception(
        'Name cannot be empty.',
      );
    }

    if (cleanedName.length < 2) {
      throw Exception(
        'Name must contain at least 2 characters.',
      );
    }

    final token =
        await _getToken();

    final response =
        await _apiClient.put(
      ApiEndpoints.profile,
      token: token,
      body: {
        'name': cleanedName,
      },
    );

    if (response is Map<String, dynamic>) {
      final user =
          response['user'];

      if (user is Map) {
        return Map<String, dynamic>.from(
          user,
        );
      }

      return response;
    }

    throw Exception(
      'Invalid profile information returned by the server.',
    );
  }

  // ============================================================
  // UPLOAD PROFILE PHOTO
  // ============================================================

  Future<Map<String, dynamic>> uploadPhoto(
    File file,
  ) async {
    final token =
        await _getToken();

    final response =
        await _apiClient.uploadFile(
      ApiEndpoints.profilePhoto,
      file: file,
      fieldName: 'photo',
      token: token,
    );

    if (response is Map<String, dynamic>) {
      final user =
          response['user'];

      if (user is Map) {
        return Map<String, dynamic>.from(
          user,
        );
      }

      return response;
    }

    throw Exception(
      'Invalid profile information returned by the server.',
    );
  }

  // ============================================================
  // REMOVE PROFILE PHOTO
  // ============================================================

  Future<Map<String, dynamic>> removePhoto() async {
    final token =
        await _getToken();

    final response =
        await _apiClient.delete(
      ApiEndpoints.profilePhoto,
      token: token,
    );

    if (response is Map<String, dynamic>) {
      final user =
          response['user'];

      if (user is Map) {
        return Map<String, dynamic>.from(
          user,
        );
      }

      return response;
    }

    throw Exception(
      'Invalid profile information returned by the server.',
    );
  }
}