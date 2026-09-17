import '/core/errors/api_exception.dart';
import '/core/network/api_client.dart';
import '/core/network/api_endpoints.dart';
import '/core/storage/auth_storage.dart';
import '/core/storage/saved_account_storage.dart';

class AuthService {
  final ApiClient _apiClient;
  final AuthStorage _storage;
  final SavedAccountStorage _savedAccountStorage;

  AuthService({
    ApiClient? apiClient,
    AuthStorage? storage,
    SavedAccountStorage? savedAccountStorage,
  })  : _apiClient =
            apiClient ?? ApiClient(),
        _storage =
            storage ?? AuthStorage(),
        _savedAccountStorage =
            savedAccountStorage ??
                SavedAccountStorage();

  Future<String> register({
    required String name,
    required String email,
    required String phoneNumber,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.register,
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'phone_number':
            phoneNumber.trim(),
      },
    );

    if (response is! Map<String, dynamic>) {
      throw const ApiException(
        'Invalid registration response.',
      );
    }

    final responseEmail =
        response['email'];

    if (responseEmail is String &&
        responseEmail.isNotEmpty) {
      return responseEmail;
    }

    return email.trim().toLowerCase();
  }

  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.verifyEmail,
      body: {
        'email': email.trim(),
        'code': code.trim(),
      },
    );

    if (response is! Map<String, dynamic>) {
      throw const ApiException(
        'Invalid verification response.',
      );
    }

    final token = response['token'];

    if (token is! String ||
        token.isEmpty) {
      throw const ApiException(
        'The server did not return an authentication token.',
      );
    }

    // Store this account as the active account.
    await _storage.saveToken(token);

    // Get the verified account information.
    final user = await getMe();

    final userId = user['id'];

    if (userId is! int) {
      throw const ApiException(
        'Invalid verified user data.',
      );
    }

    // Save this account locally so it can
    // be selected later from the account switcher.
    await _savedAccountStorage.saveAccount(
      SavedAccount(
        userId: userId,
        name:
            user['name']?.toString() ?? '',
        email:
            user['email']?.toString() ??
                email.trim().toLowerCase(),
        phoneNumber:
            user['phone_number']?.toString() ??
                '',
        token: token,
      ),
    );
  }

  Future<void> resendVerificationCode({
    required String email,
  }) async {
    await _apiClient.post(
      ApiEndpoints
          .resendVerificationCode,
      body: {
        'email': email.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> getMe() async {
    final token =
        await _storage.getToken();

    if (token == null ||
        token.isEmpty) {
      throw const ApiException(
        'No authentication token was found.',
      );
    }

    final response = await _apiClient.get(
      ApiEndpoints.me,
      token: token,
    );

    if (response is!
        Map<String, dynamic>) {
      throw const ApiException(
        'Invalid user response.',
      );
    }

    final user =
        response['user'];

    if (user is!
        Map<String, dynamic>) {
      throw const ApiException(
        'Invalid user data.',
      );
    }

    return user;
  }

  Future<String?> getStoredToken() async {
    return _storage.getToken();
  }
}