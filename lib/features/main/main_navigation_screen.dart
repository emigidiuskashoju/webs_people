import 'package:flutter/material.dart';

import '../../core/theme/webs_colors.dart';
import '../auth/screens/login_screen.dart';
import '../chats/chats_screen.dart';
import '../chats/models/preloaded_chats_data.dart';
import '../settings/settings_screen.dart';
import '../places/screens/create_place_screen.dart'; // <-- ADD THIS

class MainNavigationScreen extends StatefulWidget {
  final PreloadedChatsData? preloadedChats;

  const MainNavigationScreen({
    super.key,
    this.preloadedChats,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  late final List<Widget> _screens;
  static const int _securityTabIndex = 3; // <-- CHANGED TO 3

  @override
  void initState() {
    super.initState();
    _screens = [
      ChatsScreen(preloaded: widget.preloadedChats),
      const CreatePlaceScreen(), // <-- ADDED HERE
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
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            icon: Icon(Icons.add_location_alt_outlined), // <-- NEW ICON
            selectedIcon: Icon(Icons.add_location_alt),
            label: 'Share', // <-- NEW TAB
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
    );
  }
}