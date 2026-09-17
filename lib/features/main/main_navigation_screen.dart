import 'package:flutter/material.dart';

import '../calls/call_history_screen.dart';
import '../chats/chats_screen.dart';
import '../settings/settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({
    super.key,
  });

  @override
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState
    extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    ChatsScreen(),
    CallHistoryScreen(),
    SettingsScreen(),
  ];

  void _onNavigationItemTapped(
    int index,
  ) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),

      bottomNavigationBar:
          NavigationBar(
        selectedIndex: _currentIndex,

        onDestinationSelected:
            _onNavigationItemTapped,

        destinations: const [
          NavigationDestination(
            icon: Icon(
              Icons.chat_bubble_outline,
            ),
            selectedIcon: Icon(
              Icons.chat_bubble,
            ),
            label: 'Chats',
          ),

          NavigationDestination(
            icon: Icon(
              Icons.call_outlined,
            ),
            selectedIcon: Icon(
              Icons.call,
            ),
            label: 'Calls',
          ),

          NavigationDestination(
            icon: Icon(
              Icons.settings_outlined,
            ),
            selectedIcon: Icon(
              Icons.settings,
            ),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}