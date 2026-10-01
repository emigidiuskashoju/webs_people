import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppearanceService {
  static const String _themeModeKey =
      'webs_theme_mode';

  Future<ThemeMode> getThemeMode() async {
    final preferences =
        await SharedPreferences.getInstance();

    final value =
        preferences.getString(_themeModeKey);

    switch (value) {
      case 'light':
        return ThemeMode.light;

      case 'dark':
        return ThemeMode.dark;

      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(
    ThemeMode themeMode,
  ) async {
    final preferences =
        await SharedPreferences.getInstance();

    String value;

    switch (themeMode) {
      case ThemeMode.light:
        value = 'light';
        break;

      case ThemeMode.dark:
        value = 'dark';
        break;

      case ThemeMode.system:
        value = 'system';
        break;
    }

    await preferences.setString(
      _themeModeKey,
      value,
    );
  }
}