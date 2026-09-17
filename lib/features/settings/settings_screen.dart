import 'package:flutter/material.dart';

import '../../core/storage/auth_storage.dart';
import '../auth/register_screen.dart';
import 'about_webs_people_screen.dart';
import 'privacy_settings_screen.dart';
import 'profile_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
  });

  @override
  State<SettingsScreen> createState() =>
      _SettingsScreenState();
}

class _SettingsScreenState
    extends State<SettingsScreen> {
  bool _locationSharingEnabled = false;
  bool _notificationsEnabled = true;

  final AuthStorage _authStorage =
      AuthStorage();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Settings',
        ),
      ),
      body: ListView(
        children: [
          _buildProfileHeader(),

          const Divider(
            height: 1,
          ),

          _buildSectionTitle(
            'Account',
          ),

          _buildSettingsTile(
            icon: Icons.person_outline,
            title: 'Profile',
            subtitle:
                'Manage your personal information',
            onTap: _openProfile,
          ),

          _buildSettingsTile(
            icon: Icons.contacts_outlined,
            title: 'Contacts',
            subtitle:
                'Manage contact access',
            onTap: _openContacts,
          ),

          _buildSettingsTile(
            icon: Icons.people_outline,
            title: 'Connections',
            subtitle:
                'Manage your Webs People connections',
            onTap: _openConnections,
          ),

          _buildSectionTitle(
            'Privacy',
          ),

          SwitchListTile(
            secondary: const Icon(
              Icons.location_on_outlined,
            ),
            title: const Text(
              'Location sharing',
            ),
            subtitle: Text(
              _locationSharingEnabled
                  ? 'Your location sharing is enabled'
                  : 'Your location sharing is disabled',
            ),
            value:
                _locationSharingEnabled,
            onChanged:
                _setLocationSharing,
          ),

          _buildSettingsTile(
            icon: Icons.lock_outline,
            title: 'Privacy',
            subtitle:
                'Learn how Webs People protects your data',
            onTap: _openPrivacy,
          ),

          _buildSectionTitle(
            'Communication',
          ),

          SwitchListTile(
            secondary: const Icon(
              Icons.notifications_outlined,
            ),
            title: const Text(
              'Notifications',
            ),
            subtitle: Text(
              _notificationsEnabled
                  ? 'Notifications are enabled'
                  : 'Notifications are disabled',
            ),
            value:
                _notificationsEnabled,
            onChanged:
                _setNotifications,
          ),

          _buildSettingsTile(
            icon: Icons.call_outlined,
            title: 'Call settings',
            subtitle:
                'Audio and video call options',
            onTap: _openCallSettings,
          ),

          _buildSectionTitle(
            'App',
          ),

          _buildSettingsTile(
            icon: Icons.palette_outlined,
            title: 'Appearance',
            subtitle:
                'Choose how Webs People looks',
            onTap: _openAppearance,
          ),

          _buildSettingsTile(
            icon: Icons.info_outline,
            title: 'About Webs People',
            subtitle:
                'Information about Webs People',
            onTap: _openAbout,
          ),

          // --------------------------------------------------
          // DEVELOPMENT / TESTING
          // --------------------------------------------------

          _buildSectionTitle(
            'Development',
          ),

          _buildSettingsTile(
            icon: Icons.developer_mode_outlined,
            title: 'Reset Test Account',
            subtitle:
                'Clear local authentication and return to registration',
            onTap: _resetTestAccount,
          ),

          const SizedBox(
            height: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return InkWell(
      onTap: _openProfile,
      child: Padding(
        padding:
            const EdgeInsets.all(20),
        child: Row(
          children: [
            _buildAvatar(),

            const SizedBox(
              width: 16,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Your Profile',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  SizedBox(
                    height: 4,
                  ),

                  Text(
                    'Manage your Webs People account',
                    style: TextStyle(
                      color: Colors.grey,
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
    );
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 34,
      backgroundColor:
          Colors.green.withValues(
        alpha: 0.12,
      ),
      child: const Text(
        'Y',
        style: TextStyle(
          color: Colors.green,
          fontSize: 24,
          fontWeight:
              FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(
    String title,
  ) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        24,
        20,
        8,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight:
              FontWeight.bold,
          color:
              Theme.of(context)
                  .colorScheme
                  .primary,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 4,
      ),
      leading: Icon(
        icon,
      ),
      title: Text(
        title,
      ),
      subtitle: Text(
        subtitle,
      ),
      trailing: const Icon(
        Icons.chevron_right,
      ),
      onTap: onTap,
    );
  }

  void _setLocationSharing(
    bool enabled,
  ) {
    setState(() {
      _locationSharingEnabled =
          enabled;
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          enabled
              ? 'Location sharing enabled.'
              : 'Location sharing disabled.',
        ),
      ),
    );
  }

  void _setNotifications(
    bool enabled,
  ) {
    setState(() {
      _notificationsEnabled =
          enabled;
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          enabled
              ? 'Notifications enabled.'
              : 'Notifications disabled.',
        ),
      ),
    );
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const ProfileSettingsScreen(),
      ),
    );
  }

  void _openContacts() {
    _showComingSoon(
      'Contact settings will be connected next.',
    );
  }

  void _openConnections() {
    _showComingSoon(
      'Connection settings will be connected next.',
    );
  }

  void _openPrivacy() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const PrivacySettingsScreen(),
      ),
    );
  }

  void _openCallSettings() {
    _showComingSoon(
      'Call settings will be connected when audio and video calling are built.',
    );
  }

  void _openAppearance() {
    _showComingSoon(
      'Appearance settings will be connected next.',
    );
  }

  void _openAbout() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const AboutWebsPeopleScreen(),
      ),
    );
  }

  // ----------------------------------------------------------
  // DEVELOPMENT TEST ACCOUNT RESET
  // ----------------------------------------------------------

  Future<void> _resetTestAccount() async {
    final shouldReset =
        await showDialog<bool>(
      context: context,
      builder: (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          title: const Text(
            'Reset test account?',
          ),
          content: const Text(
            'This will clear the authentication token stored on this phone and return you to the registration screen.\n\n'
            'Your Webs People account on the server will NOT be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child: const Text(
                'Reset',
              ),
            ),
          ],
        );
      },
    );

    if (shouldReset != true) {
      return;
    }

    await _authStorage.clearToken();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
            const RegisterScreen(),
      ),
      (route) => false,
    );
  }

  void _showComingSoon(
    String message,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }
}