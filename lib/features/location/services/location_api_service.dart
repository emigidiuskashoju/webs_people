import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/auth_storage.dart';
import '../models/people_location.dart';

class LocationApiService {
  final ApiClient _apiClient;
  final AuthStorage _storage;

  LocationApiService({
    ApiClient? apiClient,
    AuthStorage? storage,
  })  : _apiClient =
            apiClient ?? ApiClient(),
        _storage =
            storage ?? AuthStorage();

  Future<void> shareLocation({
    required double latitude,
    required double longitude,
    double? accuracy,
  }) async {
    final token =
        await _storage.getToken();

    if (token == null ||
        token.isEmpty) {
      throw Exception(
        'You are not logged in.',
      );
    }

    await _apiClient.post(
      ApiEndpoints.locationShare,
      token: token,
      body: {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
      },
    );
  }

  Future<void> stopSharing() async {
    final token =
        await _storage.getToken();

    if (token == null ||
        token.isEmpty) {
      throw Exception(
        'You are not logged in.',
      );
    }

    await _apiClient.delete(
      ApiEndpoints.locationShare,
      token: token,
    );
  }

  Future<List<PeopleLocation>>
      getPeopleLocations() async {
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
      ApiEndpoints.locationPeople,
      token: token,
    );

    final locations =
        response['locations'];

    if (locations is! List) {
      return [];
    }

    return locations
        .whereType<
            Map<String, dynamic>>()
        .map(
          PeopleLocation.fromJson,
        )
        .toList();
  }
}