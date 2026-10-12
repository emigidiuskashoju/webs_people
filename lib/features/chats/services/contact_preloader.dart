import '../../../core/errors/api_exception.dart';
import '../../auth/services/auth_service.dart';
import '../../map/services/location_request_service.dart';
import '../models/phone_contact.dart';
import '../models/preloaded_chats_data.dart';
import 'contact_match_service.dart';
import 'contacts_cache_service.dart';
import 'phone_contacts_service.dart';

/// Loads everything [ChatsScreen] needs to render.
///
/// Strategy (WhatsApp-style):
///   1. If the cache is warm → return cached data immediately.
///   2. If the cache is stale (or missing) → refresh in
///      the background while still returning cached data.
///   3. If the user pulled to refresh → force a full refresh.
class ContactPreloader {
  final PhoneContactsService _contactsService;
  final ContactMatchService _matchService;
  final AuthService _authService;
  final LocationRequestService _locationService;
  final ContactsCacheService _cache;

  ContactPreloader({
    PhoneContactsService? contactsService,
    ContactMatchService? matchService,
    AuthService? authService,
    LocationRequestService? locationService,
    ContactsCacheService? cache,
  })  : _contactsService = contactsService ?? PhoneContactsService(),
        _matchService = matchService ?? ContactMatchService(),
        _authService = authService ?? AuthService(),
        _locationService = locationService ?? LocationRequestService(),
        _cache = cache ?? ContactsCacheService();

  /// Fast path — reads cache only. Never touches the phone's
  /// contact provider or the network.
  Future<PreloadedChatsData> loadFromCacheOnly() async {
    try {
      final currentUserId = await _cache.getCachedCurrentUserId();
      if (currentUserId == null) {
        // No cache yet — return empty, caller will refresh.
        return PreloadedChatsData.empty();
      }

      final contacts = await _cache.getCachedContacts();
      final matches = await _cache.getCachedMatches();

      final pendingLocationUserIds =
          await _loadPendingLocationRequestsSilently();

      return _buildPreloaded(
        currentUserId: currentUserId,
        contacts: contacts,
        matchedByPhone: matches,
        pendingLocationUserIds: pendingLocationUserIds,
      );
    } catch (e) {
      return PreloadedChatsData.empty();
    }
  }

  /// Slow path — reads phone contacts, matches against the
  /// server, saves the result to the cache, and returns the
  /// fresh [PreloadedChatsData].
  Future<PreloadedChatsData> refresh() async {
    try {
      // 1. Current user
      final currentUser = await _authService.me();
      final currentUserId = currentUser['id'];

      if (currentUserId is! int) {
        throw const ApiException('Invalid current user data.');
      }

      // 2. Read phone contacts
      final contacts = await _contactsService.getPhoneContacts();

      // 3. Pending location requests (non-fatal)
      final pendingLocationUserIds =
          await _loadPendingLocationRequestsSilently();

      if (contacts.isEmpty) {
        await _cache.saveContacts(const []);
        await _cache.saveMatches(const {});
        await _cache.saveCurrentUserId(currentUserId);
        await _cache.markSyncedNow();

        return PreloadedChatsData(
          currentUserId: currentUserId,
          allContacts: const [],
          registeredContacts: const [],
          inviteContacts: const [],
          matchedUsersByPhone: const {},
          pendingLocationRequestUserIds: pendingLocationUserIds,
        );
      }

      // 4. Match against server
      final phoneNumbers =
          contacts.map((c) => c.phoneNumber).toSet().toList();

      final matchedUsers =
          await _matchService.matchPhoneNumbers(phoneNumbers);

      final matchedByPhone = <String, ContactMatchUser>{};

      for (final user in matchedUsers) {
        final normalized =
            _contactsService.normalizePhoneNumber(user.phoneNumber);
        if (normalized == null) continue;
        matchedByPhone[normalized] = user;
      }

      // 5. Save to cache
      await _cache.saveContacts(contacts);
      await _cache.saveMatches(matchedByPhone);
      await _cache.saveCurrentUserId(currentUserId);
      await _cache.markSyncedNow();

      return _buildPreloaded(
        currentUserId: currentUserId,
        contacts: contacts,
        matchedByPhone: matchedByPhone,
        pendingLocationUserIds: pendingLocationUserIds,
      );
    } catch (e) {
      return PreloadedChatsData(
        currentUserId: 0,
        allContacts: const [],
        registeredContacts: const [],
        inviteContacts: const [],
        matchedUsersByPhone: const {},
        pendingLocationRequestUserIds: const <int>{},
        errorMessage: e.toString(),
      );
    }
  }

  Future<bool> isCacheStale() => _cache.isStale();

  Future<void> clearCache() => _cache.clear();

  // ============================================================
  // HELPERS
  // ============================================================

  Future<Set<int>> _loadPendingLocationRequestsSilently() async {
    try {
      final pending = await _locationService.getPendingRequests();
      return pending.map((request) => request.requesterId).toSet();
    } catch (_) {
      return <int>{};
    }
  }

  PreloadedChatsData _buildPreloaded({
    required int currentUserId,
    required List<PhoneContact> contacts,
    required Map<String, ContactMatchUser> matchedByPhone,
    required Set<int> pendingLocationUserIds,
  }) {
    final registered = <PhoneContact>[];
    final invites = <PhoneContact>[];

    for (final contact in contacts) {
      if (matchedByPhone.containsKey(contact.phoneNumber)) {
        registered.add(contact);
      } else {
        invites.add(contact);
      }
    }

    registered.sort(
      (a, b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    invites.sort(
      (a, b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return PreloadedChatsData(
      currentUserId: currentUserId,
      allContacts: contacts,
      registeredContacts: registered,
      inviteContacts: invites,
      matchedUsersByPhone: matchedByPhone,
      pendingLocationRequestUserIds: pendingLocationUserIds,
    );
  }
}