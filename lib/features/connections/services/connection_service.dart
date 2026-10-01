import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/connection.dart';
import '../models/connection_request.dart';

class ConnectionService {
  final ApiClient _apiClient = ApiClient();

  Future<void> sendRequest(
    int userId,
  ) async {
    await _apiClient.post(
      ApiEndpoints.connectionRequests,
      body: {
        'user_id': userId,
      },
    );
  }

  Future<List<ConnectionRequest>>
      getPendingRequests() async {
    final response = await _apiClient.get(
      ApiEndpoints.pendingConnectionRequests,
    );

    final data =
        Map<String, dynamic>.from(
      response as Map,
    );

    final requests =
        List<dynamic>.from(
      data['requests'] ?? [],
    );

    return requests
        .map(
          (item) =>
              ConnectionRequest.fromJson(
            Map<String, dynamic>.from(
              item as Map,
            ),
          ),
        )
        .toList();
  }

  Future<void> acceptRequest(
    int requestId,
  ) async {
    await _apiClient.post(
      ApiEndpoints.acceptConnectionRequest(
        requestId,
      ),
      body: {},
    );
  }

  Future<void> rejectRequest(
    int requestId,
  ) async {
    await _apiClient.post(
      ApiEndpoints.rejectConnectionRequest(
        requestId,
      ),
      body: {},
    );
  }

  Future<List<Connection>> getConnections() async {
    final response = await _apiClient.get(
      ApiEndpoints.connections,
    );

    final data =
        Map<String, dynamic>.from(
      response as Map,
    );

    final items =
        List<dynamic>.from(
      data['connections'] ?? [],
    );

    return items
        .map(
          (item) => Connection.fromJson(
            Map<String, dynamic>.from(
              item as Map,
            ),
          ),
        )
        .toList();
  }
}