import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart'; // <-- ADDED

import '../../core/theme/webs_colors.dart';
import '../auth/screens/login_screen.dart';
import '../chats/chats_screen.dart';
import '../chats/models/preloaded_chats_data.dart';
import '../settings/settings_screen.dart';
import '../updates/widgets/owner_announcement_dialog.dart';

class MainNavigationScreen extends StatefulWidget {
  /// Data the splash already loaded for the chats screen.
  ///
  /// When non-null, ChatsScreen renders instantly instead of
  /// showing its spinner. When null (e.g. after an account
  /// switch), ChatsScreen loads on its own.
  final PreloadedChatsData? preloadedChats;

  const MainNavigationScreen({
    super.key,
    this.preloadedChats,
  });

  @override
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  /// Index of the Security destination in the bottom bar.
  /// It is not a real screen — tapping it opens the login
  /// screen — so we track its position here to keep
  /// [_onNavigationItemTapped] in sync with the bar.
  static const int _securityTabIndex = 2;

  @override
  void initState() {
    super.initState();

    // --- ANALYTICS: Track main chat list open ---
    FirebaseAnalytics.instance.logEvent(
      name: 'screen_view',
      parameters: {
        'screen_name': 'chats_list',
      },
    );
    // --------------------------------------------

    _screens = [
      ChatsScreen(preloaded: widget.preloadedChats),
      const SettingsScreen(),
    ];
  }

  void _onNavigationItemTapped(int index) {
    if (index == _securityTabIndex) {
      _openSecurityLogin();
      return;
    }

    setState(() {
      _currentIndex = index;
    });
  }

  void _openSecurityLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Your main app content
        Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onNavigationItemTapped,
            backgroundColor: WebsColors.surface(context),
            indicatorColor: WebsColors.softGreen(context),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline),
                selectedIcon: Icon(Icons.chat_bubble),
                label: 'Chats',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
              NavigationDestination(
                icon: Icon(Icons.security_outlined),
                selectedIcon: Icon(Icons.security),
                label: 'Security',
              ),
            ],
          ),
        ),

        // The invisible listener that checks for owner announcements
        const OwnerAnnouncementDialog(),
      ],
    );
  }
}