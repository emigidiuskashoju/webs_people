import '../../../core/network/api_client.dart';
import '../../../core/storage/auth_storage.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/connection_request.dart';

class ConnectionApiService {
  final ApiClient _apiClient;
  final AuthStorage _storage;

  ConnectionApiService({
    ApiClient? apiClient,
    AuthStorage? storage,
  })  : _apiClient =
            apiClient ?? ApiClient(),
        _storage =
            storage ?? AuthStorage();

  Future<ConnectionRequest>
      sendRequest(
    int receiverId,
  ) async {
    final token =
        await _storage.getToken();

    if (token == null ||
        token.isEmpty) {
      throw Exception(
        'You are not logged in.',
      );
    }

    final response =
        await _apiClient.post(
      ApiEndpoints.connectionRequests,
      token: token,
      body: {
        'receiver_id': receiverId,
      },
    );

    final request =
        response['request'];

    if (request
        is! Map<String, dynamic>) {
      throw Exception(
        'Invalid connection request response.',
      );
    }

    return ConnectionRequest
        .fromJson(request);
  }

  Future<List<ConnectionRequest>>
      getPendingRequests() async {
    final token =
        await _storage.getToken();

    if (token == null ||
        token.isEmpty) {
      throw Exception(
        'You are not logged in.',
      );
    }

    final response =
        await _apiClient.get(
      ApiEndpoints
          .pendingConnectionRequests,
      token: token,
    );

    final requests =
        response['requests'];

    if (requests is! List) {
      return [];
    }

    return requests
        .whereType<
            Map<String, dynamic>>()
        .map(
          ConnectionRequest
              .fromJson,
        )
        .toList();
  }

  Future<void> acceptRequest(
    int requestId,
  ) async {
    final token =
        await _storage.getToken();

    if (token == null ||
        token.isEmpty) {
      throw Exception(
        'You are not logged in.',
      );
    }

    await _apiClient.post(
      ApiEndpoints
          .acceptConnectionRequest(
        requestId,
      ),
      token: token,
    );
  }

  Future<void> rejectRequest(
    int requestId,
  ) async {
    final token =
        await _storage.getToken();

    if (token == null ||
        token.isEmpty) {
      throw Exception(
        'You are not logged in.',
      );
    }

    await _apiClient.post(
      ApiEndpoints
          .rejectConnectionRequest(
        requestId,
      ),
      token: token,
    );
  }

  Future<List<ConnectionRequest>>
      getConnections() async {
    final token =
        await _storage.getToken();

    if (token == null ||
        token.isEmpty) {
      throw Exception(
        'You are not logged in.',
      );
    }

    final response =
        await _apiClient.get(
      ApiEndpoints.connections,
      token: token,
    );

    final connections =
        response['connections'];

    if (connections is! List) {
      return [];
    }

    return connections
        .whereType<
            Map<String, dynamic>>()
        .map(
          ConnectionRequest
              .fromJson,
        )
        .toList();
  }
}