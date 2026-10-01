import 'package:flutter/material.dart';

import '../../core/notifications/notification_preferences.dart';
import '../../core/storage/auth_storage.dart';
import '../../core/theme/webs_colors.dart';
import '../auth/register_screen.dart';
import '../../main.dart' show WebsThemeScope;
import 'about_webs_people_screen.dart';
import 'appearance_settings_screen.dart';
import 'privacy_settings_screen.dart';
import 'profile_settings_screen.dart';
import 'services/profile_service.dart';

class SettingsScreen extends StatefulWidget {
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  const SettingsScreen({
    super.key,
    this.currentThemeMode = ThemeMode.system,
    this.onThemeModeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _locationSharingEnabled = false;
  bool _notificationsEnabled = true;
  bool _notificationsLoading = true;

  final AuthStorage _authStorage = AuthStorage();
  final ProfileService _profileService = ProfileService();

  String _profileName = 'Your Profile';
  String? _profilePhotoUrl;
  bool _profileLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadNotificationPreference();
  }

  Future<void> _loadNotificationPreference() async {
    final enabled = await NotificationPreferences.instance.load();

    if (!mounted) return;

    setState(() {
      _notificationsEnabled = enabled;
      _notificationsLoading = false;
    });
  }

  Future<void> _loadProfile() async {
    try {
      final response = await _profileService.getProfile();
      final user = response['user'];

      if (user is Map) {
        final name = user['name'];
        final photoUrl = user['profile_photo_url'];
        if (!mounted) return;

        setState(() {
          if (name != null && name.toString().trim().isNotEmpty) {
            _profileName = name.toString().trim();
          }
          if (photoUrl != null &&
              photoUrl.toString().trim().isNotEmpty) {
            _profilePhotoUrl = photoUrl.toString();
          } else {
            _profilePhotoUrl = null;
          }
          _profileLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _profileLoading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _profileLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          _buildProfileHeader(),
          Divider(height: 1, color: WebsColors.border(context)),
          _buildSectionTitle('Account'),
          _buildSettingsTile(
            icon: Icons.person_outline,
            title: 'Profile',
            subtitle: 'Manage your personal information',
            onTap: _openProfile,
          ),
          _buildSettingsTile(
            icon: Icons.contacts_outlined,
            title: 'Contacts',
            subtitle: 'Manage contact access',
            onTap: _openContacts,
          ),
          _buildSettingsTile(
            icon: Icons.people_outline,
            title: 'Connections',
            subtitle: 'Manage your Webs connections',
            onTap: _openConnections,
          ),
          _buildSectionTitle('Privacy'),
          SwitchListTile(
            secondary: const Icon(Icons.location_on_outlined),
            title: const Text('Location sharing'),
            subtitle: Text(
              _locationSharingEnabled
                  ? 'Your location sharing is enabled'
                  : 'Your location sharing is disabled',
            ),
            value: _locationSharingEnabled,
            onChanged: _setLocationSharing,
            activeColor: WebsColors.primaryGreen,
          ),
          _buildSettingsTile(
            icon: Icons.lock_outline,
            title: 'Privacy',
            subtitle: 'Learn how Webs protects your data',
            onTap: _openPrivacy,
          ),
          _buildSectionTitle('Communication'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            subtitle: Text(
              _notificationsLoading
                  ? 'Loading...'
                  : _notificationsEnabled
                      ? 'Notifications are enabled'
                      : 'Notifications are disabled',
            ),
            value: _notificationsEnabled,
            onChanged: _notificationsLoading ? null : _setNotifications,
            activeColor: WebsColors.primaryGreen,
          ),
          _buildSettingsTile(
            icon: Icons.call_outlined,
            title: 'Call settings',
            subtitle: 'Audio and video call options',
            onTap: _openCallSettings,
          ),
          _buildSectionTitle('App'),
          _buildSettingsTile(
            icon: Icons.palette_outlined,
            title: 'Appearance',
            subtitle: 'Choose how Webs looks',
            onTap: _openAppearance,
          ),
          _buildSettingsTile(
            icon: Icons.info_outline,
            title: 'About Webs',
            subtitle: 'Information about Webs',
            onTap: _openAbout,
          ),
          _buildSectionTitle('Development'),
          _buildSettingsTile(
            icon: Icons.developer_mode_outlined,
            title: 'Reset Test Account',
            subtitle:
                'Clear local authentication and return to registration',
            onTap: _resetTestAccount,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return InkWell(
      onTap: _openProfile,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            _buildAvatar(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _profileLoading ? 'Loading...' : _profileName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: WebsColors.textDark(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage your Webs account',
                    style: TextStyle(color: WebsColors.textLight(context)),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: WebsColors.textLight(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (_profilePhotoUrl != null) {
      return CircleAvatar(
        radius: 34,
        backgroundImage: NetworkImage(_profilePhotoUrl!),
      );
    }

    final name = _profileName.trim();
    final firstLetter = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return CircleAvatar(
      radius: 34,
      backgroundColor: WebsColors.softGreen(context),
      child: Text(
        firstLetter,
        style: const TextStyle(
          color: WebsColors.primaryGreen,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: WebsColors.primaryGreen,
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
          const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(icon, color: WebsColors.primaryGreen),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: WebsColors.textDark(context),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: WebsColors.textLight(context)),
      ),
      trailing: Icon(Icons.chevron_right, color: WebsColors.textLight(context)),
      onTap: onTap,
    );
  }

  void _setLocationSharing(bool enabled) {
    setState(() => _locationSharingEnabled = enabled);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled ? 'Location sharing enabled.' : 'Location sharing disabled.',
        ),
      ),
    );
  }

  Future<void> _setNotifications(bool enabled) async {
    setState(() => _notificationsEnabled = enabled);

    await NotificationPreferences.instance.setEnabled(enabled);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled
              ? 'Notifications enabled.'
              : 'Notifications disabled. New messages will not show a banner.',
        ),
      ),
    );
  }

  void _openProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()),
    );
    _loadProfile();
  }

  void _openContacts() =>
      _showComingSoon('Contact settings will be connected next.');

  void _openConnections() =>
      _showComingSoon('Connection settings will be connected next.');

  void _openPrivacy() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PrivacySettingsScreen()),
    );
  }

  void _openCallSettings() => _showComingSoon(
        'Call settings will be connected when audio and video calling are built.',
      );

  void _openAppearance() {
    final themeScope = WebsThemeScope.of(context);
    if (themeScope == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AppearanceSettingsScreen(
          currentThemeMode: themeScope.themeMode,
          onThemeModeChanged: themeScope.onThemeModeChanged,
        ),
      ),
    );
  }

  void _openAbout() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AboutWebsPeopleScreen()),
    );
  }

  Future<void> _resetTestAccount() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Reset test account?'),
          content: const Text(
            'This will clear the authentication token stored on this phone and return you to the registration screen.\n\n'
            'Your Webs account on the server will NOT be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: WebsColors.primaryGreen,
              ),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (shouldReset != true) return;

    await _authStorage.clearToken();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
      (route) => false,
    );
  }

  void _showComingSoon(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}