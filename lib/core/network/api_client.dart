import 'dart:convert';

import 'package:http/http.dart' as http;

import '../errors/api_exception.dart';
import 'api_endpoints.dart';

class ApiClient {
  final http.Client _client;

  ApiClient({
    http.Client? client,
  }) : _client = client ?? http.Client();

  Map<String, String> _headers({
    String? token,
  }) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] =
          'Bearer $token';
    }

    return headers;
  }

  Future<dynamic> get(
    String endpoint, {
    String? token,
  }) async {
    try {
      final response = await _client.get(
        Uri.parse(
          '${ApiEndpoints.baseUrl}$endpoint',
        ),
        headers: _headers(
          token: token,
        ),
      );

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }

      throw const ApiException(
        'Unable to connect to the Webs People server.',
      );
    }
  }

  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse(
          '${ApiEndpoints.baseUrl}$endpoint',
        ),
        headers: _headers(
          token: token,
        ),
        body: jsonEncode(
          body ?? {},
        ),
      );

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }

      throw const ApiException(
        'Unable to connect to the Webs People server.',
      );
    }
  }

  Future<dynamic> delete(
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    try {
      final response = await _client.delete(
        Uri.parse(
          '${ApiEndpoints.baseUrl}$endpoint',
        ),
        headers: _headers(
          token: token,
        ),
        body: jsonEncode(
          body ?? {},
        ),
      );

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }

      throw const ApiException(
        'Unable to connect to the Webs People server.',
      );
    }
  }

  dynamic _handleResponse(
    http.Response response,
  ) {
    dynamic data;

    try {
      data = jsonDecode(
        response.body,
      );
    } catch (_) {
      data = null;
    }

    if (
      response.statusCode >= 200 &&
      response.statusCode < 300
    ) {
      return data ?? {};
    }

    String message =
        'Something went wrong.';

    if (data is Map<String, dynamic>) {
      if (data['message'] != null) {
        message =
            data['message'].toString();
      }

      final errors =
          data['errors'];

      if (errors is Map<String, dynamic>) {
        if (errors.isNotEmpty) {
          final firstError =
              errors.values.first;

          if (
            firstError is List &&
            firstError.isNotEmpty
          ) {
            message =
                firstError.first.toString();
          }
        }
      }
    }

    throw ApiException(
      message,
      statusCode: response.statusCode,
    );
  }
}