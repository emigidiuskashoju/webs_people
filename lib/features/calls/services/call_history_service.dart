import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/auth_storage.dart';
import '../data/call_repository.dart';
import '../models/call_record.dart';

class CallHistoryService {
  final AuthStorage _authStorage;
  final CallRepository _repository;
  final ApiClient _apiClient;

  int? _cachedUserId;

  CallHistoryService({
    AuthStorage? authStorage,
    CallRepository? repository,
    ApiClient? apiClient,
  })  : _authStorage = authStorage ?? AuthStorage(),
        _repository = repository ?? CallRepository(),
        _apiClient = apiClient ?? ApiClient();

  /// Resolve the current user's id.
  ///
  /// We cache it after the first lookup. It comes from the
  /// server's /auth/me endpoint, which is the same source
  /// the rest of the app uses.
  Future<int?> _currentUserId() async {
    if (_cachedUserId != null) {
      return _cachedUserId;
    }

    final token = await _authStorage.getToken();

    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      final response = await _apiClient.get(
        ApiEndpoints.me,
        token: token,
      );

      if (response is! Map<String, dynamic>) {
        return null;
      }

      final user = response['user'];

      if (user is! Map<String, dynamic>) {
        return null;
      }

      final id = user['id'];

      if (id is! int) {
        return null;
      }

      _cachedUserId = id;

      return id;
    } catch (e) {
      if (e is ApiException) {
        return null;
      }

      return null;
    }
  }

  Future<List<CallRecord>> getHistory() async {
    final userId = await _currentUserId();

    if (userId == null) {
      return [];
    }

    return _repository.getHistory(userId);
  }

  Future<CallRecord?> createOutgoingCall({
    required String callId,
    required int remoteUserId,
    required String remoteName,
    required String remotePhoneNumber,
    required CallType type,
  }) async {
    final userId = await _currentUserId();

    if (userId == null) {
      return null;
    }

    return _repository.createOutgoingCall(
      ownerUserId: userId,
      callId: callId,
      remoteUserId: remoteUserId,
      remoteName: remoteName,
      remotePhoneNumber: remotePhoneNumber,
      type: type,
    );
  }

  Future<CallRecord?> createIncomingCall({
    required String callId,
    required int remoteUserId,
    required String remoteName,
    required String remotePhoneNumber,
    required CallType type,
  }) async {
    final userId = await _currentUserId();

    if (userId == null) {
      return null;
    }

    return _repository.createIncomingCall(
      ownerUserId: userId,
      callId: callId,
      remoteUserId: remoteUserId,
      remoteName: remoteName,
      remotePhoneNumber: remotePhoneNumber,
      type: type,
    );
  }

  CallRepository get repository => _repository;
}