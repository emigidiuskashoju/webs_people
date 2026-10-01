import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/routes.dart';
import 'app/splash_screen.dart';
import 'core/background/background_location_service.dart';
import 'core/notifications/fcm_service.dart';
import 'core/notifications/location_notification_listener.dart';
import 'core/notifications/notification_service.dart';
import 'core/storage/auth_storage.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/calls/incoming_call_screen.dart';
import 'features/calls/models/call_record.dart';
import 'features/calls/services/call_incoming_listener.dart';
import 'features/chats/chat_screen.dart';
import 'features/chats/models/preloaded_chats_data.dart';
import 'features/chats/services/contact_preloader.dart';
import 'features/main/main_navigation_screen.dart';
import 'features/settings/services/appearance_service.dart';

final GlobalKey<NavigatorState> websNavigatorKey =
    GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    debugPrint('FIREBASE: initialised');
  } catch (e) {
    debugPrint('FIREBASE: initialisation failed: $e');
  }

  await NotificationService.instance.initialize();

  try {
    await FcmService.instance.initialize();
  } catch (e) {
    debugPrint('FCM: initialisation failed: $e');
  }

  try {
    await CallIncomingListener.instance.initialize(websNavigatorKey);
  } catch (e) {
    debugPrint('CALL-LISTENER: initialisation failed: $e');
  }

  try {
    await LocationNotificationListener.instance.initialize();
  } catch (e) {
    debugPrint('LOCATION-LISTENER: initialisation failed: $e');
  }

  // ------------------------------------------------------------------
  // Background location service
  // ------------------------------------------------------------------
  // Configures the native service but does NOT start it. Starting
  // happens when a location-sharing request is accepted.
  try {
    await BackgroundLocationService.instance.initialize();
    debugPrint('BG-SERVICE: initialised');
  } catch (e) {
    debugPrint('BG-SERVICE: initialisation failed: $e');
  }

  runApp(
    const WebsApp(),
  );
}

class WebsApp extends StatefulWidget {
  const WebsApp({
    super.key,
  });

  @override
  State<WebsApp> createState() => _WebsAppState();
}

class _WebsAppState extends State<WebsApp> {
  final AppearanceService _appearanceService = AppearanceService();
  final ContactPreloader _contactPreloader = ContactPreloader();
  final AuthStorage _authStorage = AuthStorage();

  ThemeMode _themeMode = ThemeMode.system;

  bool _appearanceLoaded = false;
  bool _splashDone = false;
  bool _tokenLoaded = false;

  PreloadedChatsData? _preloadedChats;
  String? _token;

  StreamSubscription<String>? _localNotificationTapSubscription;
  StreamSubscription<String>? _fcmTapSubscription;
  StreamSubscription<String>? _callTapSubscription;
  StreamSubscription<String>? _locationTapSubscription;

  @override
  void initState() {
    super.initState();

    _loadAppearance();
    _preloadChats();
    _loadToken();
    _listenForNotificationTaps();
    _listenForCallTaps();
    _listenForLocationTaps();
  }

  @override
  void dispose() {
    _localNotificationTapSubscription?.cancel();
    _fcmTapSubscription?.cancel();
    _callTapSubscription?.cancel();
    _locationTapSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAppearance() async {
    final themeMode = await _appearanceService.getThemeMode();
    if (!mounted) return;
    setState(() {
      _themeMode = themeMode;
      _appearanceLoaded = true;
    });
  }

  Future<void> _preloadChats() async {
    final data = await _contactPreloader.load();
    if (!mounted) return;
    setState(() => _preloadedChats = data);
  }

  Future<void> _loadToken() async {
    final token = await _authStorage.getToken();
    if (!mounted) return;
    setState(() {
      _token = token;
      _tokenLoaded = true;
    });
  }

  // ============================================================
  // NOTIFICATION TAPS
  // ============================================================

  void _listenForNotificationTaps() {
    _localNotificationTapSubscription =
        NotificationService.instance.notificationTaps.listen((payload) {
      _handleConversationTap(payload);
    });

    _fcmTapSubscription =
        FcmService.instance.messageTaps.listen((payload) {
      _handleConversationTap(payload);
    });
  }

  void _handleConversationTap(String conversationId) {
    final currentUserId = _preloadedChats?.currentUserId;
    if (currentUserId == null) return;

    final parts = conversationId.split('_');
    if (parts.length != 2) return;

    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    if (a == null || b == null) return;

    final otherUserId = a == currentUserId ? b : a;

    String name = 'Chat';
    String phoneNumber = '';
    String? profilePhotoUrl;

    final matched = _preloadedChats?.matchedUsersByPhone;
    if (matched != null) {
      for (final entry in matched.entries) {
        if (entry.value.id == otherUserId) {
          name = entry.value.name.trim().isNotEmpty
              ? entry.value.name.trim()
              : entry.key;
          phoneNumber = entry.value.phoneNumber;
          profilePhotoUrl = entry.value.profilePhotoUrl;
          break;
        }
      }
    }

    final navigator = websNavigatorKey.currentState;
    if (navigator == null) return;

    navigator.push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          currentUserId: currentUserId,
          userId: otherUserId,
          name: name,
          phoneNumber: phoneNumber,
          profilePhotoUrl: profilePhotoUrl,
        ),
      ),
    );
  }

  // ============================================================
  // CALL TAPS
  // ============================================================

  void _listenForCallTaps() {
    _callTapSubscription =
        NotificationService.instance.callTaps.listen((payload) {
      _handleCallTap(payload);
    });
  }

  void _handleCallTap(String payload) {
    final parts = payload.split(':');
    if (parts.length < 4) return;

    final callId = parts[0];
    final callerId = int.tryParse(parts[1]);
    final callerName = parts[2];
    final callerPhone = parts.sublist(3).join(':');

    if (callerId == null) return;

    final currentUserId = _preloadedChats?.currentUserId;
    if (currentUserId == null) return;

    final navigator = websNavigatorKey.currentState;
    if (navigator == null) return;

    final record = CallRecord(
      localId: callId,
      ownerUserId: currentUserId,
      callId: callId,
      remoteUserId: callerId,
      remoteName: callerName,
      remotePhoneNumber: callerPhone,
      type: CallType.audio,
      direction: CallDirection.incoming,
      status: CallStatus.ringing,
      startedAt: DateTime.now(),
      answeredAt: null,
      endedAt: null,
      durationSeconds: 0,
    );

    navigator.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => IncomingCallScreen(
          callId: callId,
          callerId: callerId,
          callerName: callerName,
          callerPhone: callerPhone,
          type: 'audio',
          record: record,
        ),
      ),
    );
  }

  // ============================================================
  // LOCATION REQUEST TAPS
  // ============================================================

  void _listenForLocationTaps() {
    _locationTapSubscription =
        NotificationService.instance.locationTaps.listen((payload) {
      _handleLocationTap(payload);
    });
  }

  void _handleLocationTap(String payload) {
    final parts = payload.split(':');
    if (parts.length < 3) return;

    final requestId = int.tryParse(parts[0]);
    final requesterId = int.tryParse(parts[1]);
    final conversationId = parts.sublist(2).join(':');

    if (requestId == null || requesterId == null) return;

    LocationNotificationListener.instance.forget(requestId);

    _handleConversationTap(conversationId);
  }

  // ============================================================
  // THEME
  // ============================================================

  Future<void> _setThemeMode(ThemeMode themeMode) async {
    setState(() => _themeMode = themeMode);
    await _appearanceService.setThemeMode(themeMode);
  }

  // ============================================================
  // SPLASH
  // ============================================================

  void _onSplashFinished() {
    if (!mounted) return;
    setState(() => _splashDone = true);
  }

  bool get _readyForApp =>
      _splashDone &&
      _appearanceLoaded &&
      _preloadedChats != null &&
      _tokenLoaded;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: websNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Webs',
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF4F9F4),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          foregroundColor: Colors.black87,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.black87),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F1A10),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50),
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      routes: WebsRoutes.routes,
      onGenerateRoute: WebsRoutes.onGenerateRoute,
      home: _buildHome(),
      builder: (BuildContext context, Widget? child) {
        return WebsThemeScope(
          themeMode: _themeMode,
          onThemeModeChanged: _setThemeMode,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildHome() {
    if (!_readyForApp) {
      return SplashScreen(
        onFinished: _onSplashFinished,
        themeMode: _themeMode,
        minimumDuration: const Duration(milliseconds: 25200),
      );
    }

    return AppStartScreen(
      preloadedChats: _preloadedChats,
      token: _token,
    );
  }
}

class WebsThemeScope extends InheritedWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const WebsThemeScope({
    required this.themeMode,
    required this.onThemeModeChanged,
    required super.child,
  });

  static WebsThemeScope? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<WebsThemeScope>();
  }

  @override
  bool updateShouldNotify(WebsThemeScope oldWidget) {
    return themeMode != oldWidget.themeMode ||
        onThemeModeChanged != oldWidget.onThemeModeChanged;
  }
}

class AppStartScreen extends StatefulWidget {
  final PreloadedChatsData? preloadedChats;
  final String? token;

  const AppStartScreen({
    super.key,
    this.preloadedChats,
    this.token,
  });

  @override
  State<AppStartScreen> createState() => _AppStartScreenState();
}

class _AppStartScreenState extends State<AppStartScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _navigate());
  }

  void _navigate() {
    if (!mounted) return;

    final navigator = Navigator.of(context);
    final token = widget.token;

    if (token != null && token.isNotEmpty) {
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => MainNavigationScreen(
            preloadedChats: widget.preloadedChats,
          ),
        ),
      );
      return;
    }

    navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) => const RegisterScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: const SizedBox.shrink(),
    );
  }
}