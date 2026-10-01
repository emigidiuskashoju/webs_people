import 'package:flutter/material.dart';

import '../../core/theme/webs_colors.dart';
import 'services/appearance_service.dart';

class AppearanceSettingsScreen extends StatefulWidget {
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const AppearanceSettingsScreen({
    super.key,
    required this.currentThemeMode,
    required this.onThemeModeChanged,
  });

  @override
  State<AppearanceSettingsScreen> createState() =>
      _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends State<AppearanceSettingsScreen> {
  final AppearanceService _appearanceService = AppearanceService();

  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.currentThemeMode;
  }

  Future<void> _selectThemeMode(ThemeMode themeMode) async {
    setState(() => _themeMode = themeMode);

    await _appearanceService.setThemeMode(themeMode);
    if (!mounted) return;

    widget.onThemeModeChanged(themeMode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text(
              'Theme',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: WebsColors.primaryGreen,
              ),
            ),
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.system,
            groupValue: _themeMode,
            activeColor: WebsColors.primaryGreen,
            title: const Text('System default'),
            subtitle: const Text('Use your phone\'s light or dark mode'),
            onChanged: (value) {
              if (value != null) _selectThemeMode(value);
            },
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.light,
            groupValue: _themeMode,
            activeColor: WebsColors.primaryGreen,
            title: const Text('Light'),
            subtitle: const Text('Always use light mode'),
            onChanged: (value) {
              if (value != null) _selectThemeMode(value);
            },
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.dark,
            groupValue: _themeMode,
            activeColor: WebsColors.primaryGreen,
            title: const Text('Dark'),
            subtitle: const Text('Always use dark mode'),
            onChanged: (value) {
              if (value != null) _selectThemeMode(value);
            },
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'This setting is saved on this phone and does not require server storage.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WebsColors.textLight(context),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}