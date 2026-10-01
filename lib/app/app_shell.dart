import 'package:flutter/material.dart';

import '../core/theme/webs_colors.dart';
import '../features/devices/devices_screen.dart';
import '../features/finding/finding_screen.dart';
import '../features/home/home_screen.dart';

class WebsAppShell extends StatefulWidget {
  const WebsAppShell({super.key});

  @override
  State<WebsAppShell> createState() => _WebsAppShellState();
}

class _WebsAppShellState extends State<WebsAppShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    DevicesScreen(),
    FindingScreen(),
  ];

  void _onNavigationItemTapped(int index) {
    if (index < 0 || index >= _screens.length) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onNavigationItemTapped,
        // Match the MainNavigationScreen look: transparent, no
        // indicator pill colour clashing with the body.
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF0A0F0B).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        indicatorColor: WebsColors.softGreen(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.devices_outlined),
            selectedIcon: Icon(Icons.devices),
            label: 'Devices',
          ),
          NavigationDestination(
            icon: Icon(Icons.radar_outlined),
            selectedIcon: Icon(Icons.radar),
            label: 'Finding',
          ),
        ],
      ),
    );
  }
}