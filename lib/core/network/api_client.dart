import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../errors/api_exception.dart';
import 'api_endpoints.dart';

class ApiClient {
  final http.Client _client;

  ApiClient({
    http.Client? client,
  }) : _client = client ?? http.Client();

  // ============================================================
  // HEADERS
  // ============================================================

  Map<String, String> _headers({
    String? token,
    String? deviceSecret,
  }) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',

      if (token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token',

      if (deviceSecret != null && deviceSecret.isNotEmpty)
        'X-Webs-Device-Secret': deviceSecret,
    };
  }

  // ============================================================
  // GET
  // ============================================================

  Future<dynamic> get(
    String endpoint, {
    String? token,
    String? deviceSecret,
  }) async {
    return _send(
      () => _client.get(
        Uri.parse(
          '${ApiEndpoints.baseUrl}$endpoint',
        ),
        headers: _headers(
          token: token,
          deviceSecret: deviceSecret,
        ),
      ),
    );
  }

  // ============================================================
  // POST
  // ============================================================

  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
    String? deviceSecret,
  }) async {
    return _send(
      () => _client.post(
        Uri.parse(
          '${ApiEndpoints.baseUrl}$endpoint',
        ),
        headers: _headers(
          token: token,
          deviceSecret: deviceSecret,
        ),
        body: jsonEncode(
          body ?? {},
        ),
      ),
    );
  }

  // ============================================================
  // PUT
  // ============================================================

  Future<dynamic> put(
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
    String? deviceSecret,
  }) async {
    return _send(
      () => _client.put(
        Uri.parse(
          '${ApiEndpoints.baseUrl}$endpoint',
        ),
        headers: _headers(
          token: token,
          deviceSecret: deviceSecret,
        ),
        body: jsonEncode(
          body ?? {},
        ),
      ),
    );
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<dynamic> delete(
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
    String? deviceSecret,
  }) async {
    return _send(
      () => _client.delete(
        Uri.parse(
          '${ApiEndpoints.baseUrl}$endpoint',
        ),
        headers: _headers(
          token: token,
          deviceSecret: deviceSecret,
        ),
        body: body == null
            ? null
            : jsonEncode(body),
      ),
    );
  }

  // ============================================================
  // MULTIPART FILE UPLOAD
  // ============================================================

  Future<dynamic> uploadFile(
    String endpoint, {
    required File file,
    required String fieldName,
    String? token,
    String? deviceSecret,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          '${ApiEndpoints.baseUrl}$endpoint',
        ),
      );

      request.headers.addAll({
        'Accept': 'application/json',

        if (token != null && token.isNotEmpty)
          'Authorization': 'Bearer $token',

        if (deviceSecret != null &&
            deviceSecret.isNotEmpty)
          'X-Webs-Device-Secret': deviceSecret,
      });

      request.files.add(
        await http.MultipartFile.fromPath(
          fieldName,
          file.path,
        ),
      );

      final streamedResponse =
          await request.send();

      final response =
          await http.Response.fromStream(
        streamedResponse,
      );

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }

      throw const ApiException(
        'Unable to upload the profile photo.',
      );
    }
  }

  // ============================================================
  // SEND REQUEST (internal)
  // ============================================================

  Future<dynamic> _send(
    Future<http.Response> Function() request,
  ) async {
    try {
      final response = await request();

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }

      throw const ApiException(
        'Unable to connect to the Webs server.',
      );
    }
  }

  // ============================================================
  // RESPONSE HANDLER
  // ============================================================

  dynamic _handleResponse(
    http.Response response,
  ) {
    dynamic data;

    if (response.body.isNotEmpty) {
      try {
        data = jsonDecode(
          response.body,
        );
      } catch (_) {
        data = response.body;
      }
    }

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return data ?? {};
    }

    String message =
        'Something went wrong.';

    if (data is Map<String, dynamic>) {
      if (data['message'] is String) {
        message =
            data['message'] as String;
      }

      final errors = data['errors'];

      if (errors is Map<String, dynamic>) {
        for (final value
            in errors.values) {
          if (value is List &&
              value.isNotEmpty) {
            final first = value.first;

            if (first is String) {
              message = first;
              break;
            }
          }
        }
      }
    }

    throw ApiException(
      message,
      statusCode:
          response.statusCode,
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  void dispose() {
    _client.close();
  }
}