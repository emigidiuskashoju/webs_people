import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/auth_storage.dart';
import 'contact_match_service.dart';

/// Names, numbers and photos of people who chatted with you but are
/// NOT saved in your phone contacts.
///
/// The phone only knows such a sender's user ID (that is all a
/// message carries). This service asks the server who that ID is
/// and keeps the answer on the phone, so the chat still shows a
/// name when offline, and after the server has cleaned up old
/// messages.
class UnknownSenderService {
  UnknownSenderService._();
  static final UnknownSenderService instance = UnknownSenderService._();

  static const String _prefsKey = 'unknown_chat_senders_v1';

  final ApiClient _apiClient = ApiClient();
  final AuthStorage _storage = AuthStorage();

  final Map<int, ContactMatchUser> _cache = {};
  bool _cacheLoaded = false;

  /// Cached user for [id], if we've looked them up before.
  ContactMatchUser? cached(int id) => _cache[id];

  /// Drops [id] from the cache so the next [resolve] asks the
  /// server again (used when they changed their name or photo).
  Future<void> forget(int id) async {
    await _loadCache();
    if (_cache.remove(id) != null) await _saveCache();
  }

  /// Returns what we know about each of [ids].
  ///
  /// Cached users come back straight away. Unknown IDs are fetched
  /// from the server; if that fails (offline), they are simply left
  /// out and the caller shows a placeholder name.
  Future<Map<int, ContactMatchUser>> resolve(Set<int> ids) async {
    await _loadCache();
    if (ids.isEmpty) return {};

    final missing = ids.where((id) => !_cache.containsKey(id)).toList();

    if (missing.isNotEmpty) {
      try {
        final fetched = await _lookup(missing);
        if (fetched.isNotEmpty) {
          for (final user in fetched) {
            _cache[user.id] = user;
          }
          await _saveCache();
        }
      } catch (_) {
        // Offline or server error: use what we have.
      }
    }

    return {
      for (final id in ids)
        if (_cache[id] != null) id: _cache[id]!,
    };
  }

  Future<List<ContactMatchUser>> _lookup(List<int> ids) async {
    final token = await _storage.getToken();
    if (token == null || token.isEmpty) {
      throw const ApiException('No authentication token was found.');
    }

    final response = await _apiClient.post(
      ApiEndpoints.contactLookup,
      token: token,
      body: {'user_ids': ids},
    );

    if (response is! Map<String, dynamic>) return const [];
    final users = response['users'];
    if (users is! List) return const [];

    return users
        .whereType<Map<String, dynamic>>()
        .map(ContactMatchUser.fromJson)
        .toList();
  }

  Future<void> _loadCache() async {
    if (_cacheLoaded) return;
    _cacheLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final list = jsonDecode(raw);
      if (list is! List) return;
      for (final item in list.whereType<Map<String, dynamic>>()) {
        try {
          final user = ContactMatchUser.fromJson(item);
          _cache[user.id] = user;
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _cache.values
          .map((u) => {
                'id': u.id,
                'name': u.name,
                'phone_number': u.phoneNumber,
                'profile_photo_url': u.profilePhotoUrl,
              })
          .toList();
      await prefs.setString(_prefsKey, jsonEncode(list));
    } catch (_) {}
  }
}
