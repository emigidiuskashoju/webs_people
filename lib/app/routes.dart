import 'package:flutter/material.dart';

import '../features/auth/screens/create_password_screen.dart';
import '../features/auth/screens/email_verification_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/terms_screen.dart';
import '../features/devices/devices_screen.dart';
import '../features/finding/finding_screen.dart';
import '../features/location/location_screen.dart';
import '../features/lost_mode/lost_mode_screen.dart';

import 'app_shell.dart';

class WebsRoutes {
  // ============================================================
  // AUTHENTICATION ROUTES
  // ============================================================

  static const String login = '/login';

  static const String register = '/register';

  static const String verifyEmail = '/verify-email';

  static const String terms = '/terms';

  static const String createPassword = '/create-password';

  // ============================================================
  // SECURITY SYSTEM ROUTES
  // ============================================================

  static const String security = '/security';

  static const String devices = '/devices';

  static const String location = '/location';

  static const String lostMode = '/lost-mode';

  static const String finding = '/finding';

  static const String profile = '/profile';

  // ============================================================
  // NORMAL APPLICATION ROUTES
  // ============================================================

  static final Map<String, WidgetBuilder> routes = {
    // ----------------------------------------------------------
    // LOGIN
    // ----------------------------------------------------------

    login: (_) => const LoginScreen(),

    // ----------------------------------------------------------
    // REGISTER
    // ----------------------------------------------------------

    register: (_) => const RegisterScreen(),

    // ----------------------------------------------------------
    // EMAIL VERIFICATION
    // ----------------------------------------------------------

    verifyEmail: (context) {
      final arguments = ModalRoute.of(context)?.settings.arguments;

      if (arguments is! String || arguments.trim().isEmpty) {
        return const RegisterScreen();
      }

      return EmailVerificationScreen(
        email: arguments,
      );
    },

    // ----------------------------------------------------------
    // TERMS & CONDITIONS
    // ----------------------------------------------------------
    //
    // Shown after email verification.
    //
    // Expects the verified email as a String argument, which it
    // forwards to the Create Password screen once the user
    // accepts the terms.

    terms: (context) {
      final arguments = ModalRoute.of(context)?.settings.arguments;

      if (arguments is! String || arguments.trim().isEmpty) {
        return const RegisterScreen();
      }

      return TermsScreen(
        email: arguments,
      );
    },

    // ----------------------------------------------------------
    // CREATE PASSWORD
    // ----------------------------------------------------------

    createPassword: (context) {
      final arguments = ModalRoute.of(context)?.settings.arguments;

      if (arguments is! String || arguments.trim().isEmpty) {
        return const RegisterScreen();
      }

      return CreatePasswordScreen(
        email: arguments,
      );
    },

    // ----------------------------------------------------------
    // SECURITY SYSTEM
    // ----------------------------------------------------------

    security: (_) => const WebsAppShell(),

    // ----------------------------------------------------------
    // SECURITY SCREENS
    // ----------------------------------------------------------

    devices: (_) => const DevicesScreen(),

    location: (_) => const LocationScreen(),

    lostMode: (_) => const LostModeScreen(),

    finding: (_) => const FindingScreen(),
  };

  // ============================================================
  // GENERATED ROUTES
  // ============================================================

  static Route<dynamic>? onGenerateRoute(
    RouteSettings settings,
  ) {
    switch (settings.name) {
      // --------------------------------------------------------
      // ROOT
      // --------------------------------------------------------
      //
      // The root is still available for the application shell.
      // It is NOT placed inside the routes map because
      // main.dart already uses home: AppStartScreen().
      //

      case '/':
        return MaterialPageRoute(
          builder: (_) => const WebsAppShell(),
          settings: settings,
        );

      default:
        return null;
    }
  }
}