import 'package:flutter/material.dart';

class WebsColors {
  // Brand colors — identical in both themes
  static const Color darkGreen = Color(0xFF1B5E20);
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color accentGreen = Color(0xFF4CAF50);

  // Light theme
  static const Color lightBg = Color(0xFFF4F9F4);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSoftGreen = Color(0xFFE8F5E9);
  static const Color lightTextDark = Color(0xFF1B1B1B);
  static const Color lightTextLight = Color(0xFF666666);

  // Dark theme
  static const Color darkBg = Color(0xFF0F1A10);
  static const Color darkSurface = Color(0xFF1A261B);
  static const Color darkSoftGreen = Color(0xFF243826);
  static const Color darkTextDark = Color(0xFFF1F8F2);
  static const Color darkTextLight = Color(0xFFA8B8A9);

  // Theme-aware getters
  static Color surface(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? darkSurface : lightSurface;

  static Color softGreen(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? darkSoftGreen : lightSoftGreen;

  static Color textDark(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? darkTextDark : lightTextDark;

  static Color textLight(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? darkTextLight : lightTextLight;

  static Color border(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark
          ? const Color(0xFF2E4530)
          : lightSoftGreen;

  static Color shadow(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark
          ? Colors.black.withValues(alpha: 0.4)
          : darkGreen.withValues(alpha: 0.05);
}