import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/errors/api_exception.dart';
import '../../core/storage/auth_storage.dart';
import '../../core/storage/saved_account_storage.dart';
import '../auth/services/auth_service.dart';
import '../main/main_navigation_screen.dart';
import 'chat_screen.dart';
import 'models/phone_contact.dart';
import 'services/contact_match_service.dart';
import 'services/phone_contacts_service.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({
    super.key,
  });

  @override
  State<ChatsScreen> createState() =>
      _ChatsScreenState();
}

class _ChatsScreenState
    extends State<ChatsScreen> {
  final PhoneContactsService
      _contactsService =
      PhoneContactsService();

  final ContactMatchService
      _matchService =
      ContactMatchService();

  final AuthService _authService =
      AuthService();

  final SavedAccountStorage
      _savedAccountStorage =
      SavedAccountStorage();

  final AuthStorage _authStorage =
      AuthStorage();

  int? _currentUserId;

  bool _isLoading = true;

  String? _errorMessage;

  List<PhoneContact> _allContacts = [];

  List<PhoneContact>
      _registeredContacts = [];

  List<PhoneContact>
      _inviteContacts = [];

  Map<String, ContactMatchUser>
      _matchedUsersByPhone = {};

  @override
  void initState() {
    super.initState();

    _loadContacts();
  }

  Future<void> _loadContacts() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // Get the currently authenticated
      // Webs People user.
      final currentUser =
          await _authService.getMe();

      final currentUserId =
          currentUser['id'];

      if (currentUserId is! int) {
        throw const ApiException(
          'Invalid current user data.',
        );
      }

      _currentUserId = currentUserId;

      // Read the contacts stored locally
      // on this phone.
      final contacts =
          await _contactsService
              .getPhoneContacts();

      if (!mounted) {
        return;
      }

      if (contacts.isEmpty) {
        setState(() {
          _allContacts = [];
          _registeredContacts = [];
          _inviteContacts = [];
          _matchedUsersByPhone = {};
          _isLoading = false;
        });

        return;
      }

      // Extract only the phone numbers
      // required for matching.
      final phoneNumbers =
          contacts
              .map(
                (contact) =>
                    contact.phoneNumber,
              )
              .toSet()
              .toList();

      // Ask the server which of those
      // phone numbers belong to Webs People users.
      final matchedUsers =
          await _matchService
              .matchPhoneNumbers(
        phoneNumbers,
      );

      final matchedByPhone =
          <String, ContactMatchUser>{};

      for (final user in matchedUsers) {
        final normalized =
            _contactsService
                .normalizePhoneNumber(
          user.phoneNumber,
        );

        if (normalized == null) {
          continue;
        }

        matchedByPhone[normalized] =
            user;
      }

      final registered =
          <PhoneContact>[];

      final invites =
          <PhoneContact>[];

      for (final contact in contacts) {
        if (matchedByPhone
            .containsKey(
          contact.phoneNumber,
        )) {
          registered.add(contact);
        } else {
          invites.add(contact);
        }
      }

      registered.sort(
        (a, b) => a.name
            .toLowerCase()
            .compareTo(
              b.name.toLowerCase(),
            ),
      );

      invites.sort(
        (a, b) => a.name
            .toLowerCase()
            .compareTo(
              b.name.toLowerCase(),
            ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _allContacts = contacts;

        _registeredContacts =
            registered;

        _inviteContacts =
            invites;

        _matchedUsersByPhone =
            matchedByPhone;

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
            e.toString();
      });
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading:
            false,

        title: const Row(
          children: [
            Icon(
              Icons.hub,
              color: Colors.green,
            ),

            SizedBox(width: 10),

            Text(
              'Webs People',
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            onPressed:
                _showAccountSwitcher,
            tooltip:
                'Switch account',
            icon: const Icon(
              Icons.swap_horiz,
            ),
          ),

          const SizedBox(width: 8),
        ],
      ),

      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Future<void> _showAccountSwitcher() async {
    final accounts =
        await _savedAccountStorage
            .getAccounts();

    if (!mounted) {
      return;
    }

    final currentToken =
        await _authStorage.getToken();

    if (!mounted) {
      return;
    }

    if (accounts.isEmpty) {
      _showMessage(
        'No other saved accounts are available.',
      );

      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              24,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Switch account',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  'Choose a saved Webs People account.',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 16),

                ...accounts.map(
                  (account) {
                    final isCurrent =
                        account.token ==
                            currentToken;

                    final displayName =
                        account.name
                                .trim()
                                .isNotEmpty
                            ? account.name
                                .trim()
                            : 'Webs People user';

                    return ListTile(
                      contentPadding:
                          EdgeInsets.zero,

                      leading:
                          CircleAvatar(
                        backgroundColor:
                            Colors.green
                                .withValues(
                          alpha: 0.12,
                        ),
                        child: Text(
                          displayName
                                  .isNotEmpty
                              ? displayName[
                                  0]
                                  .toUpperCase()
                              : '?',
                          style:
                              const TextStyle(
                            color:
                                Colors.green,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),

                      title:
                          Text(
                        displayName,
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),

                      subtitle:
                          Text(
                        account.email
                                .trim()
                                .isNotEmpty
                            ? account.email
                            : account.phoneNumber,
                      ),

                      trailing:
                          isCurrent
                              ? const Icon(
                                  Icons
                                      .check_circle,
                                  color:
                                      Colors.green,
                                )
                              : const Icon(
                                  Icons
                                      .chevron_right,
                                ),

                      onTap: isCurrent
                          ? null
                          : () async {
                              Navigator.of(
                                context,
                              ).pop();

                              await _switchAccount(
                                account,
                              );
                            },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _switchAccount(
    SavedAccount account,
  ) async {
    try {
      await _authStorage.saveToken(
        account.token,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context)
          .pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              const MainNavigationScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Could not switch account.',
      );
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_allContacts.isEmpty) {
      return _buildEmptyContactsState();
    }

    return RefreshIndicator(
      onRefresh:
          _loadContacts,

      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),

        padding:
            const EdgeInsets.fromLTRB(
          20,
          20,
          20,
          32,
        ),

        children: [
          const Text(
            'Chats',
            style: TextStyle(
              fontSize: 28,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'People from your phone contacts who use Webs People.',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(
                context,
              )
                  .colorScheme
                  .onSurface
                  .withValues(
                    alpha: 0.60,
                  ),
            ),
          ),

          const SizedBox(height: 24),

          _buildRegisteredSection(),

          const SizedBox(height: 28),

          const Divider(),

          const SizedBox(height: 24),

          _buildInviteSection(),
        ],
      ),
    );
  }

  Widget _buildRegisteredSection() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Webs People',
          style: TextStyle(
            fontSize: 19,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(height: 10),

        if (_registeredContacts
            .isEmpty)
          _buildSectionEmpty(
            icon:
                Icons.people_outline,
            text:
                'None of your phone contacts are using Webs People yet.',
          )
        else
          ..._registeredContacts.map(
            (contact) {
              final user =
                  _matchedUsersByPhone[
                      contact.phoneNumber];

              if (user == null) {
                return const SizedBox
                    .shrink();
              }

              return Padding(
                padding:
                    const EdgeInsets.only(
                  bottom: 10,
                ),
                child:
                    _buildRegisteredUserTile(
                  contact,
                  user,
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildInviteSection() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Invite to Webs People',
          style: TextStyle(
            fontSize: 19,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          'Contacts who are not registered with Webs People.',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(
              context,
            )
                .colorScheme
                .onSurface
                .withValues(
                  alpha: 0.60,
                ),
          ),
        ),

        const SizedBox(height: 12),

        if (_inviteContacts.isEmpty)
          _buildSectionEmpty(
            icon:
                Icons.check_circle_outline,
            text:
                'All contacts with phone numbers are already using Webs People.',
          )
        else
          ..._inviteContacts.map(
            (contact) {
              return Padding(
                padding:
                    const EdgeInsets.only(
                  bottom: 10,
                ),
                child:
                    _buildInviteUserTile(
                  contact,
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildRegisteredUserTile(
    PhoneContact contact,
    ContactMatchUser user,
  ) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,

      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(18),

        side: BorderSide(
          color: Theme.of(context)
              .colorScheme
              .outline
              .withValues(
                alpha: 0.15,
              ),
        ),
      ),

      child: InkWell(
        borderRadius:
            BorderRadius.circular(18),

        onTap: () {
          _openChat(
            contact,
            user,
          );
        },

        child: Padding(
          padding:
              const EdgeInsets.all(14),

          child: Row(
            children: [
              _buildAvatar(
                contact.name,
              ),

              const SizedBox(
                width: 14,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,

                  children: [
                    Text(
                      contact.name,
                      style:
                          const TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      'Webs People user',
                      style:
                          TextStyle(
                        fontSize: 13,
                        color: Theme.of(
                          context,
                        )
                            .colorScheme
                            .onSurface
                            .withValues(
                              alpha: 0.55,
                            ),
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInviteUserTile(
    PhoneContact contact,
  ) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,

      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(18),

        side: BorderSide(
          color: Theme.of(context)
              .colorScheme
              .outline
              .withValues(
                alpha: 0.15,
              ),
        ),
      ),

      child: InkWell(
        borderRadius:
            BorderRadius.circular(18),

        onTap: () {
          _inviteContact(
            contact,
          );
        },

        child: Padding(
          padding:
              const EdgeInsets.all(14),

          child: Row(
            children: [
              _buildAvatar(
                contact.name,
                isInvite: true,
              ),

              const SizedBox(
                width: 14,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,

                  children: [
                    Text(
                      contact.name,
                      style:
                          const TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    const Text(
                      'Not registered',
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.person_add_alt_1,
                color: Colors.green,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(
    String name, {
    bool isInvite = false,
  }) {
    final letter =
        name.isNotEmpty
            ? name[0].toUpperCase()
            : '?';

    return Container(
      width: 52,
      height: 52,

      decoration:
          BoxDecoration(
        color: isInvite
            ? Colors.grey.withValues(
                alpha: 0.12,
              )
            : Colors.green.withValues(
                alpha: 0.12,
              ),

        shape:
            BoxShape.circle,
      ),

      alignment:
          Alignment.center,

      child: Text(
        letter,

        style: TextStyle(
          fontSize: 20,
          fontWeight:
              FontWeight.bold,

          color: isInvite
              ? Colors.grey
              : Colors.green,
        ),
      ),
    );
  }

  Future<void> _openChat(
    PhoneContact contact,
    ContactMatchUser user,
  ) async {
    final currentUserId =
        _currentUserId;

    if (currentUserId == null) {
      _showMessage(
        'Your user information is not available. Please refresh and try again.',
      );

      return;
    }

    if (currentUserId == user.id) {
      _showMessage(
        'You cannot start a chat with yourself.',
      );

      return;
    }

    await Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) =>
            ChatScreen(
          currentUserId:
              currentUserId,

          userId:
              user.id,

          name:
              contact.name,

          phoneNumber:
              contact.phoneNumber,
        ),
      ),
    );
  }

  Future<void> _inviteContact(
    PhoneContact contact,
  ) async {
    final message =
        'Hi ${contact.name}, '
        'I am using Webs People. '
        'Join me on Webs People so we can connect privately.';

    final smsUri = Uri(
      scheme: 'sms',
      path:
          contact.phoneNumber,
      queryParameters: {
        'body': message,
      },
    );

    try {
      final launched =
          await launchUrl(
        smsUri,
        mode:
            LaunchMode
                .externalApplication,
      );

      if (!launched &&
          mounted) {
        _showMessage(
          'Could not open the SMS application.',
        );
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Could not open the SMS application.',
        );
      }
    }
  }

  Widget _buildSectionEmpty({
    required IconData icon,
    required String text,
  }) {
    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(24),

      decoration:
          BoxDecoration(
        color:
            Colors.grey.withValues(
          alpha: 0.07,
        ),

        borderRadius:
            BorderRadius.circular(18),
      ),

      child: Column(
        children: [
          Icon(
            icon,
            size: 42,
            color:
                Colors.grey,
          ),

          const SizedBox(
            height: 10,
          ),

          Text(
            text,
            textAlign:
                TextAlign.center,

            style:
                const TextStyle(
              color:
                  Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),

        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            const Icon(
              Icons.contacts_outlined,
              size: 60,
              color: Colors.grey,
            ),

            const SizedBox(
              height: 16,
            ),

            const Text(
              'We could not load your contacts.',
              textAlign:
                  TextAlign.center,

              style:
                  TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              _errorMessage ??
                  'Please try again.',
              textAlign:
                  TextAlign.center,

              style:
                  const TextStyle(
                color: Colors.grey,
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            ElevatedButton.icon(
              onPressed:
                  _loadContacts,

              icon:
                  const Icon(
                Icons.refresh,
              ),

              label:
                  const Text(
                'Try again',
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
        padding:
            const EdgeInsets.all(24),

        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            const Icon(
              Icons.contacts_outlined,
              size: 64,
              color: Colors.grey,
            ),

            const SizedBox(
              height: 18,
            ),

            const Text(
              'No contacts found.',
              style:
                  TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            const Text(
              'Add phone numbers to your phone contacts and refresh Webs People.',
              textAlign:
                  TextAlign.center,

              style:
                  TextStyle(
                color: Colors.grey,
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            ElevatedButton.icon(
              onPressed:
                  _loadContacts,

              icon:
                  const Icon(
                Icons.refresh,
              ),

              label:
                  const Text(
                'Refresh contacts',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
            Text(message),
      ),
    );
  }
}