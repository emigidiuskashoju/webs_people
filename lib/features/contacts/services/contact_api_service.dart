import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/auth_storage.dart';
import '../models/contact_match.dart';

class ContactApiService {
  final ApiClient _apiClient;
  final AuthStorage _storage;

  ContactApiService({
    ApiClient? apiClient,
    AuthStorage? storage,
  })  : _apiClient =
            apiClient ?? ApiClient(),
        _storage =
            storage ?? AuthStorage();

  Future<List<ContactMatch>> matchContacts(
    List<String> phoneNumbers,
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
      ApiEndpoints.contactMatch,
      token: token,
      body: {
        'phone_numbers': phoneNumbers,
      },
    );

    if (response
        is! Map<String, dynamic>) {
      throw Exception(
        'Invalid contact match response.',
      );
    }

    final matches =
        response['matches'];

    if (matches is! List) {
      return [];
    }

    return matches
        .whereType<Map<String, dynamic>>()
        .map(
          ContactMatch.fromJson,
        )
        .toList();
  }
}