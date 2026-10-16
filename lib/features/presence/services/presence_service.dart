import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/auth_storage.dart';
import '../models/user_presence.dart';

class PresenceService {
  final ApiClient _apiClient;
  final AuthStorage _authStorage;

  PresenceService({
    ApiClient? apiClient,
    AuthStorage? authStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _authStorage = authStorage ?? AuthStorage();

  /// Server-enforced cap. Matches PresenceController's
  /// MAX_USER_IDS_PER_REQUEST.
  static const int maxUserIdsPerCall = 100;

  Future<String> _token() async {
    final token = await _authStorage.getToken();

    if (token == null || token.isEmpty) {
      throw const ApiException(
        'No authentication token was found.',
      );
    }

    return token;
  }

  /// Called on a timer and immediately on typing.
  ///
  /// Pass `typingInConversation` (e.g. "1_3") while the user is
  /// typing in a chat, and `null` when not typing.
  Future<void> heartbeat({
    String? typingInConversation,
  }) async {
    final token = await _token();

    await _apiClient.post(
      ApiEndpoints.presenceHeartbeat,
      token: token,
      body: {
        'typing_in_conversation': typingInConversation,
      },
    );
  }

  /// Fetch one user's presence. Used by the chat screen.
  Future<UserPresence> getForUser(int userId) async {
    final token = await _token();

    final response = await _apiClient.get(
      ApiEndpoints.presenceForUser(userId),
      token: token,
    );

    if (response is! Map<String, dynamic>) {
      throw const ApiException(
        'Invalid presence response.',
      );
    }

    final raw = response['presence'];

    if (raw is! Map) {
      throw const ApiException(
        'Invalid presence payload.',
      );
    }

    return UserPresence.fromJson(
      userId,
      Map<String, dynamic>.from(raw),
    );
  }

  /// Fetch presence for a specific set of users.
  ///
  /// Silently drops duplicates and non-positive ids. If the
  /// input list is empty, returns an empty map without making
  /// a request.
  ///
  /// If more than [maxUserIdsPerCall] unique ids are supplied,
  /// the call is chunked into multiple requests and the results
  /// are merged. In practice the chats list will never hit this.
  Future<Map<int, UserPresence>> getForUsers(
    Iterable<int> userIds,
  ) async {
    final uniqueIds = <int>{};

    for (final id in userIds) {
      if (id > 0) uniqueIds.add(id);
    }

    if (uniqueIds.isEmpty) return {};

    final ids = uniqueIds.toList();

    final result = <int, UserPresence>{};

    for (var i = 0; i < ids.length; i += maxUserIdsPerCall) {
      final end = (i + maxUserIdsPerCall) > ids.length
          ? ids.length
          : i + maxUserIdsPerCall;

      final chunk = ids.sublist(i, end);

      final chunkResult = await _fetchPresenceChunk(chunk);

      result.addAll(chunkResult);
    }

    return result;
  }

  Future<Map<int, UserPresence>> _fetchPresenceChunk(
    List<int> userIds,
  ) async {
    final token = await _token();

    final query = userIds.join(',');

    final path =
        '${ApiEndpoints.presenceIndex}?user_ids=$query';

    final response = await _apiClient.get(
      path,
      token: token,
    );

    if (response is! Map<String, dynamic>) {
      throw const ApiException(
        'Invalid presence response.',
      );
    }

    final raw = response['presences'];

    if (raw is! Map) return {};

    final parsed = <int, UserPresence>{};

    raw.forEach((key, value) {
      final userId = int.tryParse(key.toString());
      if (userId == null) return;
      if (value is! Map) return;

      parsed[userId] = UserPresence.fromJson(
        userId,
        Map<String, dynamic>.from(value),
      );
    });

    return parsed;
  }
}