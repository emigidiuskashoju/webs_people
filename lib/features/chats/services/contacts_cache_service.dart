import '../data/contact_cache_db.dart';
import '../models/phone_contact.dart';
import 'contact_match_service.dart';

/// High-level wrapper around [ContactCacheDb].
///
/// Public API:
///   - Read cache (instant)
///   - Refresh from phone + server
///   - Check staleness
///   - Clear on logout
class ContactsCacheService {
  static const Duration _defaultMaxAge = Duration(hours: 12);

  final ContactCacheDb _db;

  ContactsCacheService({ContactCacheDb? db})
      : _db = db ?? ContactCacheDb();

  // ============================================================
  // READ (instant, no network, no disk reads of phone contacts)
  // ============================================================

  Future<List<PhoneContact>> getCachedContacts() {
    return _db.readContacts();
  }

  Future<Map<String, ContactMatchUser>> getCachedMatches() {
    return _db.readMatches();
  }

  Future<int?> getCachedCurrentUserId() {
    return _db.readCurrentUserId();
  }

  Future<bool> hasCache() async {
    final contacts = await _db.readContacts();
    return contacts.isNotEmpty;
  }

  // ============================================================
  // STALENESS
  // ============================================================

  Future<bool> isStale({
    Duration maxAge = _defaultMaxAge,
  }) async {
    final lastSync = await _db.readLastSyncAt();

    if (lastSync == null) return true;

    return DateTime.now().difference(lastSync) > maxAge;
  }

  // ============================================================
  // WRITE
  // ============================================================

  Future<void> saveContacts(List<PhoneContact> contacts) {
    return _db.writeContacts(contacts);
  }

  Future<void> saveMatches(
    Map<String, ContactMatchUser> matches,
  ) {
    return _db.writeMatches(matches);
  }

  Future<void> markSyncedNow() {
    return _db.writeLastSyncAt(DateTime.now());
  }

  Future<void> saveCurrentUserId(int userId) {
    return _db.writeCurrentUserId(userId);
  }

  // ============================================================
  // CLEAR
  // ============================================================

  Future<void> clear() {
    return _db.clear();
  }
}