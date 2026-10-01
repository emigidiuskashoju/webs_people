import '../../../core/errors/api_exception.dart';
import '../../auth/services/auth_service.dart';
import '../../map/services/location_request_service.dart';
import '../models/phone_contact.dart';
import '../models/preloaded_chats_data.dart';
import 'contact_match_service.dart';
import 'phone_contacts_service.dart';

class ContactPreloader {
  final PhoneContactsService _contactsService;
  final ContactMatchService _matchService;
  final AuthService _authService;
  final LocationRequestService _locationService;

  ContactPreloader({
    PhoneContactsService? contactsService,
    ContactMatchService? matchService,
    AuthService? authService,
    LocationRequestService? locationService,
  })  : _contactsService = contactsService ?? PhoneContactsService(),
        _matchService = matchService ?? ContactMatchService(),
        _authService = authService ?? AuthService(),
        _locationService = locationService ?? LocationRequestService();

  Future<PreloadedChatsData> load() async {
    try {
      // 1. Who is the current user?
      final currentUser = await _authService.me();
      final currentUserId = currentUser['id'];

      if (currentUserId is! int) {
        throw const ApiException('Invalid current user data.');
      }

      // 2. Read phone contacts.
      final contacts =
          await _contactsService.getPhoneContacts();

      // 3. Fetch pending location requests in parallel.
      Set<int> pendingLocationUserIds = <int>{};

      try {
        final pending =
            await _locationService.getPendingRequests();

        pendingLocationUserIds = pending
            .map((request) => request.requesterId)
            .toSet();
      } catch (_) {
        // Non-fatal. The chats list still renders.
      }

      if (contacts.isEmpty) {
        return PreloadedChatsData(
          currentUserId: currentUserId,
          allContacts: const [],
          registeredContacts: const [],
          inviteContacts: const [],
          matchedUsersByPhone: const {},
          pendingLocationRequestUserIds:
              pendingLocationUserIds,
        );
      }

      // 4. Match contacts to Webs users.
      final phoneNumbers = contacts
          .map((c) => c.phoneNumber)
          .toSet()
          .toList();

      final matchedUsers =
          await _matchService.matchPhoneNumbers(phoneNumbers);

      final matchedByPhone = <String, ContactMatchUser>{};

      for (final user in matchedUsers) {
        final normalized =
            _contactsService.normalizePhoneNumber(user.phoneNumber);

        if (normalized == null) continue;

        matchedByPhone[normalized] = user;
      }

      // 5. Split into registered / invite.
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
        (a, b) => a.name
            .toLowerCase()
            .compareTo(b.name.toLowerCase()),
      );

      invites.sort(
        (a, b) => a.name
            .toLowerCase()
            .compareTo(b.name.toLowerCase()),
      );

      return PreloadedChatsData(
        currentUserId: currentUserId,
        allContacts: contacts,
        registeredContacts: registered,
        inviteContacts: invites,
        matchedUsersByPhone: matchedByPhone,
        pendingLocationRequestUserIds:
            pendingLocationUserIds,
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
}