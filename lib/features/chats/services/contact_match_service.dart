import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/auth_storage.dart';

class ContactMatchUser {
  final int id;
  final String name;
  final String phoneNumber;
  final String? profilePhotoUrl;

  const ContactMatchUser({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.profilePhotoUrl,
  });

  factory ContactMatchUser.fromJson(
    Map<String, dynamic> json,
  ) {
    final id = json['id'];

    if (id is! int) {
      throw const ApiException(
        'Invalid matched user ID.',
      );
    }

    return ContactMatchUser(
      id: id,
      name: json['name']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString() ?? '',
      profilePhotoUrl:
          json['profile_photo_url']?.toString(),
    );
  }
}

class ContactMatchService {
  final ApiClient _apiClient;
  final AuthStorage _storage;

  ContactMatchService({
    ApiClient? apiClient,
    AuthStorage? storage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _storage = storage ?? AuthStorage();

  Future<List<ContactMatchUser>> matchPhoneNumbers(
    List<String> phoneNumbers,
  ) async {
    final token = await _storage.getToken();

    if (token == null || token.isEmpty) {
      throw const ApiException(
        'No authentication token was found.',
      );
    }

    final response = await _apiClient.post(
      ApiEndpoints.contactMatch,
      token: token,
      body: {
        'phone_numbers': phoneNumbers,
      },
    );

    if (response is! Map<String, dynamic>) {
      throw const ApiException(
        'Invalid contact matching response.',
      );
    }

    final users = response['users'];

    if (users is! List) {
      throw const ApiException(
        'Invalid contact matching data.',
      );
    }

    return users
        .whereType<Map<String, dynamic>>()
        .map(ContactMatchUser.fromJson)
        .toList();
  }
}