import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/errors/api_exception.dart';
import '../../core/storage/auth_storage.dart';
import '../../core/storage/saved_account_storage.dart';
import '../../core/theme/webs_colors.dart';
import '../../core/widgets/webs_background.dart';
import '../auth/services/auth_service.dart';
import '../main/main_navigation_screen.dart';
import '../map/services/location_request_service.dart';
import 'chat_screen.dart';
import 'data/chat_database.dart';
import 'data/chat_repository.dart';
import 'models/phone_contact.dart';
import 'models/preloaded_chats_data.dart';
import 'services/contact_match_service.dart';
import 'services/phone_contacts_service.dart';

class ChatsScreen extends StatefulWidget {
  final PreloadedChatsData? preloaded;

  const ChatsScreen({
    super.key,
    this.preloaded,
  });

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final PhoneContactsService _contactsService = PhoneContactsService();
  final ContactMatchService _matchService = ContactMatchService();
  final AuthService _authService = AuthService();
  final SavedAccountStorage _savedAccountStorage = SavedAccountStorage();
  final AuthStorage _authStorage = AuthStorage();
  final ChatRepository _chatRepository = ChatRepository();
  final LocationRequestService _locationRequestService =
      LocationRequestService();

  final TextEditingController _searchController = TextEditingController();

  int? _currentUserId;
  bool _isLoading = true;
  String? _errorMessage;

  List<PhoneContact> _allContacts = [];
  List<PhoneContact> _registeredContacts = [];
  List<PhoneContact> _inviteContacts = [];
  Map<String, ContactMatchUser> _matchedUsersByPhone = {};

  Map<String, ConversationSummary> _summaries = {};

  Set<int> _pendingLocationUserIds = <int>{};

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_onSearchChanged);

    final preloaded = widget.preloaded;

    if (preloaded != null) {
      _currentUserId = preloaded.currentUserId;
      _allContacts = preloaded.allContacts;
      _registeredContacts = preloaded.registeredContacts;
      _inviteContacts = preloaded.inviteContacts;
      _matchedUsersByPhone = preloaded.matchedUsersByPhone;
      _pendingLocationUserIds =
          preloaded.pendingLocationRequestUserIds;
      _errorMessage = preloaded.errorMessage;
      _isLoading = false;

      _loadSummariesAndPending();

      return;
    }

    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();

    if (query == _searchQuery) return;

    setState(() {
      _searchQuery = query;
    });
  }

  // ============================================================
  // SEARCH FILTERING
  // ============================================================

  List<PhoneContact> _applySearch(List<PhoneContact> input) {
    if (_searchQuery.isEmpty) return input;

    return input.where((contact) {
      final name = contact.name.toLowerCase();
      final phone = contact.phoneNumber.toLowerCase();

      final digitsQuery =
          _searchQuery.replaceAll(RegExp(r'\D'), '');
      final digitsPhone =
          phone.replaceAll(RegExp(r'\D'), '');

      final matchesName = name.contains(_searchQuery);

      final matchesPhone = digitsQuery.isNotEmpty
          ? digitsPhone.contains(digitsQuery)
          : phone.contains(_searchQuery);

      return matchesName || matchesPhone;
    }).toList();
  }

  // ============================================================
  // LOAD / REFRESH
  // ============================================================

  Future<void> _loadSummariesAndPending() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;

    try {
      await _chatRepository.receivePendingMessages(
        currentUserId: currentUserId,
      );
    } catch (_) {}

    await _refreshPendingLocationRequests(silent: true);

    try {
      final summaries =
          await _chatRepository.getConversationSummaries(
        currentUserId: currentUserId,
      );

      if (!mounted) return;

      setState(() {
        _summaries = summaries;
        _registeredContacts =
            _sortRegistered(_registeredContacts);
      });
    } catch (_) {}
  }

  Future<void> _refreshPendingLocationRequests({
    bool silent = false,
  }) async {
    try {
      final requests =
          await _locationRequestService.getPendingRequests();

      final ids = requests
          .map((request) => request.requesterId)
          .toSet();

      if (!mounted) return;

      setState(() {
        _pendingLocationUserIds = ids;
      });
    } catch (_) {
      if (silent) return;
    }
  }

  List<PhoneContact> _sortRegistered(List<PhoneContact> input) {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return input;

    final copy = List<PhoneContact>.from(input);

    copy.sort((a, b) {
      final userA = _matchedUsersByPhone[a.phoneNumber];
      final userB = _matchedUsersByPhone[b.phoneNumber];

      DateTime? lastA;
      DateTime? lastB;

      if (userA != null) {
        final convId = _chatRepository.createConversationId(
          currentUserId,
          userA.id,
        );
        lastA = _summaries[convId]?.lastMessageAt;
      }

      if (userB != null) {
        final convId = _chatRepository.createConversationId(
          currentUserId,
          userB.id,
        );
        lastB = _summaries[convId]?.lastMessageAt;
      }

      if (lastA != null && lastB == null) return -1;
      if (lastA == null && lastB != null) return 1;

      if (lastA != null && lastB != null) {
        final byTime = lastB.compareTo(lastA);
        if (byTime != 0) return byTime;
      }

      return a.name
          .toLowerCase()
          .compareTo(b.name.toLowerCase());
    });

    return copy;
  }

  Future<int> _ensureCurrentUserId() async {
    final cached = _currentUserId;
    if (cached != null) return cached;

    final currentUser = await _authService.me();
    final id = currentUser['id'];

    if (id is! int) {
      throw const ApiException('Invalid current user data.');
    }

    _currentUserId = id;
    return id;
  }

  Future<void> _loadContacts() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      await _ensureCurrentUserId();

      final currentUserId = _currentUserId!;

      try {
        await _chatRepository.receivePendingMessages(
          currentUserId: currentUserId,
        );
      } catch (_) {}

      await _refreshPendingLocationRequests(silent: true);

      final contacts =
          await _contactsService.getPhoneContacts();
      if (!mounted) return;

      if (contacts.isEmpty) {
        setState(() {
          _allContacts = [];
          _registeredContacts = [];
          _inviteContacts = [];
          _matchedUsersByPhone = {};
          _summaries = {};
          _isLoading = false;
        });
        return;
      }

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

      final registered = <PhoneContact>[];
      final invites = <PhoneContact>[];

      for (final contact in contacts) {
        if (matchedByPhone.containsKey(contact.phoneNumber)) {
          registered.add(contact);
        } else {
          invites.add(contact);
        }
      }

      final summaries =
          await _chatRepository.getConversationSummaries(
        currentUserId: currentUserId,
      );

      if (!mounted) return;

      registered.sort((a, b) {
        final userA = matchedByPhone[a.phoneNumber];
        final userB = matchedByPhone[b.phoneNumber];

        DateTime? lastA;
        DateTime? lastB;

        if (userA != null) {
          final convId = _chatRepository.createConversationId(
            currentUserId,
            userA.id,
          );
          lastA = summaries[convId]?.lastMessageAt;
        }

        if (userB != null) {
          final convId = _chatRepository.createConversationId(
            currentUserId,
            userB.id,
          );
          lastB = summaries[convId]?.lastMessageAt;
        }

        if (lastA != null && lastB == null) return -1;
        if (lastA == null && lastB != null) return 1;

        if (lastA != null && lastB != null) {
          final byTime = lastB.compareTo(lastA);
          if (byTime != 0) return byTime;
        }

        return a.name
            .toLowerCase()
            .compareTo(b.name.toLowerCase());
      });

      invites.sort((a, b) => a.name
          .toLowerCase()
          .compareTo(b.name.toLowerCase()));

      if (!mounted) return;

      setState(() {
        _allContacts = contacts;
        _registeredContacts = registered;
        _inviteContacts = invites;
        _matchedUsersByPhone = matchedByPhone;
        _summaries = summaries;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Row(
          children: [
            Icon(Icons.hub),
            SizedBox(width: 10),
            Text('Webs'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showAccountSwitcher,
            tooltip: 'Switch account',
            icon: const Icon(Icons.swap_horiz),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RepaintBoundary(
        child: WebsBackground(
          child: _buildBody(),
        ),
      ),
    );
  }

  // ============================================================
  // ACCOUNT SWITCHER
  // ============================================================

  Future<void> _showAccountSwitcher() async {
    final accounts = await _savedAccountStorage.getAccounts();
    if (!mounted) return;

    final currentToken = await _authStorage.getToken();
    if (!mounted) return;

    if (accounts.isEmpty) {
      _showMessage('No other saved accounts are available.');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: WebsColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Switch account',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: WebsColors.textDark(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose a saved Webs account.',
                  style: TextStyle(
                    color: WebsColors.textLight(context),
                  ),
                ),
                const SizedBox(height: 16),
                ...accounts.map((account) {
                  final isCurrent = account.token == currentToken;

                  final displayName =
                      account.name.trim().isNotEmpty
                          ? account.name.trim()
                          : 'Webs user';

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: WebsColors.softGreen(context),
                      child: Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: WebsColors.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: WebsColors.textDark(context),
                      ),
                    ),
                    subtitle: Text(
                      account.email.trim().isNotEmpty
                          ? account.email
                          : account.phoneNumber,
                      style: TextStyle(
                        color: WebsColors.textLight(context),
                      ),
                    ),
                    trailing: isCurrent
                        ? const Icon(
                            Icons.check_circle,
                            color: WebsColors.primaryGreen,
                          )
                        : Icon(
                            Icons.chevron_right,
                            color: WebsColors.textLight(context),
                          ),
                    onTap: isCurrent
                        ? null
                        : () async {
                            Navigator.of(context).pop();
                            await _switchAccount(account);
                          },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

 Future<void> _switchAccount(SavedAccount account) async {
  try {
    // Switch account properly: this stops tracking, tears down
    // the old heartbeat, saves the new token, re-registers this
    // phone under the new account, and re-registers FCM.
    await _authService.switchAccount(account.token);

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const MainNavigationScreen(),
      ),
      (route) => false,
    );
  } catch (e) {
    if (!mounted) return;
    _showMessage('Could not switch account.');
  }
}

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: WebsColors.primaryGreen,
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_allContacts.isEmpty) {
      return _buildEmptyContactsState();
    }

    final filteredRegistered =
        _applySearch(_registeredContacts);
    final filteredInvites =
        _applySearch(_inviteContacts);

    final items = <_ChatListItem>[
      const _ChatListItem.header(),
      const _ChatListItem.sectionTitle(title: 'Webs'),
      if (filteredRegistered.isEmpty)
        _ChatListItem.sectionEmpty(
          icon: _searchQuery.isEmpty
              ? Icons.people_outline
              : Icons.search_off,
          text: _searchQuery.isEmpty
              ? 'None of your phone contacts are using Webs yet.'
              : 'No registered contacts match "$_searchQuery".',
        )
      else
        ...filteredRegistered.map(
          (contact) => _ChatListItem.registered(contact),
        ),
      const _ChatListItem.spacer(28),
      const _ChatListItem.divider(),
      const _ChatListItem.spacer(24),
      const _ChatListItem.sectionTitle(title: 'Invite to Webs'),
      const _ChatListItem.sectionSubtitle(
        text: 'Contacts who are not registered with Webs.',
      ),
      if (filteredInvites.isEmpty)
        _ChatListItem.sectionEmpty(
          icon: _searchQuery.isEmpty
              ? Icons.check_circle_outline
              : Icons.search_off,
          text: _searchQuery.isEmpty
              ? 'All contacts with phone numbers are already using Webs.'
              : 'No unregistered contacts match "$_searchQuery".',
        )
      else
        ...filteredInvites.map(
          (contact) => _ChatListItem.invite(contact),
        ),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            style: TextStyle(
              color: WebsColors.textDark(context),
            ),
            decoration: InputDecoration(
              hintText: 'Search by name or phone number',
              hintStyle: TextStyle(
                color: WebsColors.textLight(context),
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: WebsColors.primaryGreen,
              ),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: Icon(
                        Icons.close,
                        color: WebsColors.textLight(context),
                      ),
                      onPressed: () {
                        _searchController.clear();
                      },
                    ),
              filled: true,
              fillColor: WebsColors.softGreen(context),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(
                  color: WebsColors.primaryGreen,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: WebsColors.primaryGreen,
            onRefresh: _loadContacts,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];

                switch (item.kind) {
                  case _ChatListItemKind.header:
                    return RepaintBoundary(
                      child: _buildHeader(),
                    );

                  case _ChatListItemKind.sectionTitle:
                    return RepaintBoundary(
                      child: _buildSectionTitle(item.title ?? ''),
                    );

                  case _ChatListItemKind.sectionSubtitle:
                    return RepaintBoundary(
                      child: _buildSectionSubtitle(item.text ?? ''),
                    );

                  case _ChatListItemKind.sectionEmpty:
                    return RepaintBoundary(
                      child: _buildSectionEmpty(
                        icon: item.icon ?? Icons.info_outline,
                        text: item.text ?? '',
                      ),
                    );

                  case _ChatListItemKind.registered:
                    final contact = item.contact!;
                    final user =
                        _matchedUsersByPhone[contact.phoneNumber];

                    if (user == null) {
                      return const SizedBox.shrink();
                    }

                    return RepaintBoundary(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildRegisteredUserTile(contact, user),
                      ),
                    );

                  case _ChatListItemKind.invite:
                    final contact = item.contact!;

                    return RepaintBoundary(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildInviteUserTile(contact),
                      ),
                    );

                  case _ChatListItemKind.divider:
                    return RepaintBoundary(
                      child: Divider(
                        color: WebsColors.border(context),
                        thickness: 2,
                      ),
                    );

                  case _ChatListItemKind.spacer:
                    return SizedBox(height: item.height ?? 0);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chats',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: WebsColors.textDark(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'People from your phone contacts who use Webs.',
          style: TextStyle(
            fontSize: 14,
            color: WebsColors.textLight(context),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.bold,
        color: WebsColors.textDark(context),
      ),
    );
  }

  Widget _buildSectionSubtitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        color: WebsColors.textLight(context),
      ),
    );
  }

  Widget _buildRegisteredAvatar(
    PhoneContact contact,
    ContactMatchUser user,
  ) {
    final profilePhotoUrl = user.profilePhotoUrl;

    if (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 28,
        backgroundImage: NetworkImage(profilePhotoUrl),
        backgroundColor: WebsColors.softGreen(context),
      );
    }

    final displayName = user.name.trim().isNotEmpty
        ? user.name.trim()
        : contact.name.trim();

    final initial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return CircleAvatar(
      radius: 28,
      backgroundColor: WebsColors.softGreen(context),
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: WebsColors.primaryGreen,
        ),
      ),
    );
  }

  Widget _buildRegisteredUserTile(
    PhoneContact contact,
    ContactMatchUser user,
  ) {
    final currentUserId = _currentUserId;

    final displayName = user.name.trim().isNotEmpty
        ? user.name.trim()
        : contact.name.trim();

    ConversationSummary? summary;
    if (currentUserId != null) {
      final conversationId = _chatRepository.createConversationId(
        currentUserId,
        user.id,
      );
      summary = _summaries[conversationId];
    }

    final unreadCount = summary?.unreadCount ?? 0;

    final hasLocationRequest =
        _pendingLocationUserIds.contains(user.id);

    return Container(
      decoration: BoxDecoration(
        color: WebsColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: WebsColors.border(context),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openChat(user, contact),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _buildRegisteredAvatar(contact, user),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: WebsColors.textDark(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildPreviewLine(summary),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _buildTrailing(
                  unreadCount: unreadCount,
                  hasLocationRequest: hasLocationRequest,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewLine(ConversationSummary? summary) {
    final light = WebsColors.textLight(context);

    if (summary == null) {
      return Text(
        '',
        style: TextStyle(fontSize: 13, color: light),
      );
    }

    final prefix = summary.lastMessageIsMine ? 'You: ' : '';
    final timeLabel = _formatRelativeTime(summary.lastMessageAt);

    return Row(
      children: [
        Expanded(
          child: Text(
            '$prefix${summary.lastMessageText}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: light),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          timeLabel,
          style: TextStyle(fontSize: 12, color: light),
        ),
      ],
    );
  }

  Widget _buildTrailing({
    required int unreadCount,
    required bool hasLocationRequest,
  }) {
    if (unreadCount > 0 || hasLocationRequest) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasLocationRequest)
            Container(
              constraints: const BoxConstraints(
                minWidth: 26,
                minHeight: 26,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 7,
                vertical: 3,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF25D366),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text(
                'R',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (hasLocationRequest && unreadCount > 0)
            const SizedBox(width: 6),
          if (unreadCount > 0)
            Container(
              constraints: const BoxConstraints(
                minWidth: 26,
                minHeight: 26,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 7,
                vertical: 3,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF25D366),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: WebsColors.softGreen(context),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.chevron_right,
        color: WebsColors.primaryGreen,
        size: 20,
      ),
    );
  }

  String _formatRelativeTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} hr';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days';

    final day = time.day.toString().padLeft(2, '0');
    final month = time.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  Widget _buildInviteUserTile(PhoneContact contact) {
    return Container(
      decoration: BoxDecoration(
        color: WebsColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: WebsColors.border(context),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _inviteContact(contact),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _buildAvatar(contact.name, isInvite: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: WebsColors.textDark(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        contact.phoneNumber,
                        style: TextStyle(
                          fontSize: 13,
                          color: WebsColors.textLight(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: WebsColors.softGreen(context),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1,
                    color: WebsColors.primaryGreen,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(
    String name, {
    bool isInvite = false,
  }) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: isInvite
            ? WebsColors.textLight(context).withValues(alpha: 0.15)
            : WebsColors.softGreen(context),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: isInvite
              ? WebsColors.textLight(context)
              : WebsColors.primaryGreen,
        ),
      ),
    );
  }

  Future<void> _openChat(
    ContactMatchUser user,
    PhoneContact contact,
  ) async {
    final currentUserId = _currentUserId;

    if (currentUserId == null) {
      _showMessage(
        'Your user information is not available. Please refresh and try again.',
      );
      return;
    }

    if (currentUserId == user.id) {
      _showMessage('You cannot start a chat with yourself.');
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          currentUserId: currentUserId,
          userId: user.id,
          name: user.name.trim().isNotEmpty
              ? user.name.trim()
              : contact.name,
          phoneNumber: user.phoneNumber,
          profilePhotoUrl: user.profilePhotoUrl,
        ),
      ),
    );

    if (!mounted) return;
    await _loadSummariesAndPending();
  }

  Future<void> _inviteContact(PhoneContact contact) async {
    final message = 'Hi ${contact.name}, '
        'I am using Webs. '
        'Join me on Webs so we can connect privately.';

    final smsUri = Uri(
      scheme: 'sms',
      path: contact.phoneNumber,
      queryParameters: {'body': message},
    );

    try {
      final launched = await launchUrl(
        smsUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        _showMessage('Could not open the SMS application.');
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Could not open the SMS application.');
      }
    }
  }

  Widget _buildSectionEmpty({
    required IconData icon,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: WebsColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: WebsColors.border(context),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: WebsColors.softGreen(context),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 42,
              color: WebsColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: WebsColors.textLight(context),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: WebsColors.softGreen(context),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.contacts_outlined,
                size: 56,
                color: WebsColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'We could not load your contacts.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: WebsColors.textDark(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Please try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: WebsColors.textLight(context)),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadContacts,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(
                backgroundColor: WebsColors.primaryGreen,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyContactsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: WebsColors.softGreen(context),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.contacts_outlined,
                size: 56,
                color: WebsColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No contacts found.',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: WebsColors.textDark(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add phone numbers to your phone contacts and refresh Webs.',
              textAlign: TextAlign.center,
              style: TextStyle(color: WebsColors.textLight(context)),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadContacts,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh contacts'),
              style: FilledButton.styleFrom(
                backgroundColor: WebsColors.primaryGreen,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

// ================================================================
// FLAT LIST ITEM MODEL
// ================================================================

enum _ChatListItemKind {
  header,
  sectionTitle,
  sectionSubtitle,
  sectionEmpty,
  registered,
  invite,
  divider,
  spacer,
}

class _ChatListItem {
  final _ChatListItemKind kind;
  final PhoneContact? contact;
  final String? title;
  final String? text;
  final IconData? icon;
  final double? height;

  const _ChatListItem.header()
      : kind = _ChatListItemKind.header,
        contact = null,
        title = null,
        text = null,
        icon = null,
        height = null;

  const _ChatListItem.sectionTitle({required String title})
      : kind = _ChatListItemKind.sectionTitle,
        contact = null,
        title = title,
        text = null,
        icon = null,
        height = null;

  const _ChatListItem.sectionSubtitle({required String text})
      : kind = _ChatListItemKind.sectionSubtitle,
        contact = null,
        title = null,
        text = text,
        icon = null,
        height = null;

  const _ChatListItem.sectionEmpty({
    required IconData icon,
    required String text,
  })  : kind = _ChatListItemKind.sectionEmpty,
        contact = null,
        title = null,
        text = text,
        icon = icon,
        height = null;

  const _ChatListItem.registered(this.contact)
      : kind = _ChatListItemKind.registered,
        title = null,
        text = null,
        icon = null,
        height = null;

  const _ChatListItem.invite(this.contact)
      : kind = _ChatListItemKind.invite,
        title = null,
        text = null,
        icon = null,
        height = null;

  const _ChatListItem.divider()
      : kind = _ChatListItemKind.divider,
        contact = null,
        title = null,
        text = null,
        icon = null,
        height = null;

  const _ChatListItem.spacer(this.height)
      : kind = _ChatListItemKind.spacer,
        contact = null,
        title = null,
        text = null,
        icon = null;
}