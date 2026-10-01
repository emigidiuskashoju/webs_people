import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/auth_storage.dart';
import '../models/custom_route.dart';

class CustomRouteService {
  final ApiClient _apiClient;
  final AuthStorage _authStorage;

  CustomRouteService({
    ApiClient? apiClient,
    AuthStorage? authStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _authStorage = authStorage ?? AuthStorage();

  Future<String> _getToken() async {
    final token = await _authStorage.getToken();

    if (token == null || token.isEmpty) {
      throw const FormatException(
        'No authentication token is available.',
      );
    }

    return token;
  }

  Future<CustomRoute> createRoute({
    required int locationRequestId,
    required List<CustomRoutePoint> points,
  }) async {
    final token = await _getToken();

    if (points.length < 2) {
      throw const FormatException(
        'At least two route points are required.',
      );
    }

    final response = await _apiClient.post(
      ApiEndpoints.customRoutes,
      token: token,
      body: {
        'location_request_id': locationRequestId,
        'points': points
            .map((point) => point.toJson())
            .toList(),
      },
    );

    if (response is! Map) {
      throw const FormatException(
        'Invalid custom route response.',
      );
    }

    final data = Map<String, dynamic>.from(
      response,
    );

    final route = data['route'];

    if (route is! Map) {
      throw const FormatException(
        'Custom route was not returned.',
      );
    }

    return CustomRoute.fromJson(
      Map<String, dynamic>.from(route),
    );
  }

  Future<CustomRoute?> getRoute(
    int locationRequestId,
  ) async {
    final token = await _getToken();

    try {
      final response = await _apiClient.get(
        ApiEndpoints.customRoute(
          locationRequestId,
        ),
        token: token,
      );

      if (response is! Map) {
        return null;
      }

      final data = Map<String, dynamic>.from(
        response,
      );

      final route = data['route'];

      if (route is! Map) {
        return null;
      }

      return CustomRoute.fromJson(
        Map<String, dynamic>.from(route),
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> deleteRoute(
    int locationRequestId,
  ) async {
    final token = await _getToken();

    await _apiClient.delete(
      ApiEndpoints.customRoute(
        locationRequestId,
      ),
      token: token,
    );
  }
}