import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/auth_storage.dart';
import '../models/location_request.dart';

class LocationRequestService {
  final ApiClient _apiClient;
  final AuthStorage _authStorage;

  LocationRequestService({
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

  Future<DailyCodeResult> generateDailyCode() async {
    final token = await _getToken();

    final response = await _apiClient.post(
      ApiEndpoints.locationCode,
      body: {},
      token: token,
    );

    if (response is! Map) {
      throw const FormatException(
        'Invalid daily location code response.',
      );
    }

    final data = Map<String, dynamic>.from(response);

    final code = data['code']?.toString() ?? '';

    final expiresAt = DateTime.tryParse(
      data['expires_at']?.toString() ?? '',
    );

    if (code.isEmpty || expiresAt == null) {
      throw const FormatException(
        'Invalid daily location code data.',
      );
    }

    return DailyCodeResult(
      code: code,
      expiresAt: expiresAt,
    );
  }

  Future<LocationRequest> requestLocation(
    String code,
  ) async {
    final token = await _getToken();

    final response = await _apiClient.post(
      ApiEndpoints.locationRequests,
      body: {
        'code': code,
      },
      token: token,
    );

    if (response is! Map) {
      throw const FormatException(
        'Invalid location request response.',
      );
    }

    final data = Map<String, dynamic>.from(response);

    final request = data['request'];

    if (request is! Map) {
      throw const FormatException(
        'Location request was not returned.',
      );
    }

    return LocationRequest.fromJson(
      Map<String, dynamic>.from(request),
    );
  }

  Future<List<LocationRequest>> getPendingRequests() async {
    final token = await _getToken();

    final response = await _apiClient.get(
      ApiEndpoints.pendingLocationRequests,
      token: token,
    );

    if (response is! Map) {
      throw const FormatException(
        'Invalid pending location requests response.',
      );
    }

    final data = Map<String, dynamic>.from(response);

    final raw = data['requests'];

    if (raw is! List) {
      return [];
    }

    return raw
        .whereType<Map>()
        .map(
          (item) => LocationRequest.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<List<LocationRequest>> getConversationRequests(
    int userId,
  ) async {
    final token = await _getToken();

    final response = await _apiClient.get(
      ApiEndpoints.locationConversationRequests(
        userId,
      ),
      token: token,
    );

    if (response is! Map) {
      throw const FormatException(
        'Invalid conversation location requests response.',
      );
    }

    final data = Map<String, dynamic>.from(response);

    final raw = data['requests'];

    if (raw is! List) {
      return [];
    }

    return raw
        .whereType<Map>()
        .map(
          (item) => LocationRequest.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<LocationRequest> acceptRequest(
    int requestId,
  ) async {
    final token = await _getToken();

    final response = await _apiClient.post(
      ApiEndpoints.acceptLocationRequest(
        requestId,
      ),
      body: {},
      token: token,
    );

    return _requestFromResponse(response);
  }

  Future<LocationRequest> denyRequest(
    int requestId,
  ) async {
    final token = await _getToken();

    final response = await _apiClient.post(
      ApiEndpoints.denyLocationRequest(
        requestId,
      ),
      body: {},
      token: token,
    );

    return _requestFromResponse(response);
  }

  Future<void> updateLocation({
    required int requestId,
    required double latitude,
    required double longitude,
    double? accuracy,
  }) async {
    final token = await _getToken();

    await _apiClient.post(
      ApiEndpoints.locationRequestLocation(
        requestId,
      ),
      body: {
        'latitude': latitude,
        'longitude': longitude,
        if (accuracy != null) 'accuracy': accuracy,
      },
      token: token,
    );
  }

  Future<LocationDataResult?> getLocation(
    int requestId,
  ) async {
    final token = await _getToken();

    final response = await _apiClient.get(
      ApiEndpoints.locationRequestLocation(
        requestId,
      ),
      token: token,
    );

    if (response is! Map) {
      return null;
    }

    final data = Map<String, dynamic>.from(response);

    final raw = data['location'];

    if (raw is! Map) {
      return null;
    }

    final location = Map<String, dynamic>.from(raw);

    final latitude = _toDouble(
      location['latitude'],
    );

    final longitude = _toDouble(
      location['longitude'],
    );

    if (latitude == null || longitude == null) {
      return null;
    }

    return LocationDataResult(
      latitude: latitude,
      longitude: longitude,
      accuracy: _toDouble(
        location['accuracy'],
      ),
      updatedAt: DateTime.tryParse(
        location['updated_at']?.toString() ?? '',
      ),
    );
  }

  LocationRequest _requestFromResponse(
    dynamic response,
  ) {
    if (response is! Map) {
      throw const FormatException(
        'Invalid location request response.',
      );
    }

    final data = Map<String, dynamic>.from(response);

    final request = data['request'];

    if (request is! Map) {
      throw const FormatException(
        'Location request was not returned.',
      );
    }

    return LocationRequest.fromJson(
      Map<String, dynamic>.from(request),
    );
  }

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ?? '',
    );
  }
}

class DailyCodeResult {
  final String code;
  final DateTime expiresAt;

  const DailyCodeResult({
    required this.code,
    required this.expiresAt,
  });
}

class LocationDataResult {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime? updatedAt;

  const LocationDataResult({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.updatedAt,
  });
}