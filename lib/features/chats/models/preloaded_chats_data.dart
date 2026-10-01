import 'phone_contact.dart';
import '../services/contact_match_service.dart';

/// Everything ChatsScreen needs to render its list without
/// calling the contact services again.
class PreloadedChatsData {
  final int currentUserId;

  final List<PhoneContact> allContacts;
  final List<PhoneContact> registeredContacts;
  final List<PhoneContact> inviteContacts;
  final Map<String, ContactMatchUser> matchedUsersByPhone;

  /// User ids of people who have sent the current user a
  /// pending location request. Used to show the "R" badge.
  final Set<int> pendingLocationRequestUserIds;

  final String? errorMessage;

  const PreloadedChatsData({
    required this.currentUserId,
    required this.allContacts,
    required this.registeredContacts,
    required this.inviteContacts,
    required this.matchedUsersByPhone,
    this.pendingLocationRequestUserIds = const <int>{},
    this.errorMessage,
  });

  factory PreloadedChatsData.empty() {
    return const PreloadedChatsData(
      currentUserId: 0,
      allContacts: [],
      registeredContacts: [],
      inviteContacts: [],
      matchedUsersByPhone: {},
      pendingLocationRequestUserIds: <int>{},
    );
  }

  bool get hasError => errorMessage != null;

  bool get isEmpty => allContacts.isEmpty;

  bool hasPendingLocationFrom(int userId) {
    return pendingLocationRequestUserIds.contains(userId);
  }

  PreloadedChatsData copyWith({
    int? currentUserId,
    List<PhoneContact>? allContacts,
    List<PhoneContact>? registeredContacts,
    List<PhoneContact>? inviteContacts,
    Map<String, ContactMatchUser>? matchedUsersByPhone,
    Set<int>? pendingLocationRequestUserIds,
    String? errorMessage,
  }) {
    return PreloadedChatsData(
      currentUserId: currentUserId ?? this.currentUserId,
      allContacts: allContacts ?? this.allContacts,
      registeredContacts:
          registeredContacts ?? this.registeredContacts,
      inviteContacts:
          inviteContacts ?? this.inviteContacts,
      matchedUsersByPhone:
          matchedUsersByPhone ?? this.matchedUsersByPhone,
      pendingLocationRequestUserIds:
          pendingLocationRequestUserIds ??
              this.pendingLocationRequestUserIds,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}