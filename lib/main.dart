import 'package:flutter/material.dart';

import 'core/storage/auth_storage.dart';
import 'features/auth/register_screen.dart';
import 'features/main/main_navigation_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const WebsApp(),
  );
}

class WebsApp extends StatelessWidget {
  const WebsApp({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'Webs People',

      theme: ThemeData(
        useMaterial3: true,

        colorScheme:
            ColorScheme.fromSeed(
          seedColor: Colors.green,
        ),
      ),

      home:
          const AppStartScreen(),
    );
  }
}

class AppStartScreen
    extends StatefulWidget {
  const AppStartScreen({
    super.key,
  });

  @override
  State<AppStartScreen> createState() =>
      _AppStartScreenState();
}

class _AppStartScreenState
    extends State<AppStartScreen> {
  final AuthStorage _storage =
      AuthStorage();

  @override
  void initState() {
    super.initState();

    _checkAuthentication();
  }

  Future<void>
      _checkAuthentication() async {
    final token =
        await _storage.getToken();

    if (!mounted) {
      return;
    }

    if (token != null &&
        token.isNotEmpty) {
      Navigator.of(context)
          .pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              const MainNavigationScreen(),
        ),
      );

      return;
    }

    Navigator.of(context)
        .pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            const RegisterScreen(),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return const Scaffold(
      body: Center(
        child:
            CircularProgressIndicator(),
      ),
    );
  }
}