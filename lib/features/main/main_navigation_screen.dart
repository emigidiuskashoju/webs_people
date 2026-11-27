import 'package:flutter/material.dart';

import '../../core/notifications/notification_tap_gate.dart';
import '../../core/theme/webs_colors.dart';
import '../bestwinger/bw_links.dart';
import '../bestwinger/bw_track_screen.dart';
import '../chats/chats_screen.dart';
import '../chats/models/preloaded_chats_data.dart';
import '../settings/settings_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _screens = [
      ChatsScreen(preloaded: widget.preloadedChats),
      const SettingsScreen(),
      // Replaces the old Security tab: meet the buyer / seller of a
      // Shopicky delivery on the map (works with the website too).
      const BwTrackScreen(),
    ];
    // Now a tapped notification can open its chat on top of this
    // screen (including one tapped while the app was starting).
    NotificationTapGate.instance.markReadyAfterFirstFrame();
    // Same for "Track in Webs" links from the Shopicky website.
    BwLinks.instance.markReadyAfterFirstFrame();
  }

  @override
  void dispose() {
    NotificationTapGate.instance.markNotReady();
    BwLinks.instance.markNotReady();
    super.dispose();
  }

  void _onNavigationItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
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
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping),
            label: 'Track',
          ),
        ],
      ),
    );
  }
}