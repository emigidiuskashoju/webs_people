import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart'; // <-- ADDED
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/routes.dart';
import 'app/splash_screen.dart';
import 'core/background/background_location_service.dart';
import 'core/notifications/fcm_service.dart';
import 'core/notifications/location_notification_listener.dart';
import 'core/notifications/active_conversation.dart';
import 'core/notifications/notification_service.dart';
import 'core/notifications/notification_tap_gate.dart';
import 'core/storage/auth_storage.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/bestwinger/bw_links.dart';
import 'features/chats/chat_screen.dart';
import 'features/chats/models/preloaded_chats_data.dart';
import 'features/chats/services/contact_preloader.dart';
import 'features/main/main_navigation_screen.dart';
import 'features/presence/presence_heartbeat.dart';
import 'features/settings/services/appearance_service.dart';
import 'features/update/update_gate.dart';

final GlobalKey<NavigatorState> websNavigatorKey =
    GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase MUST be ready before the app starts.
  try {
    await Firebase.initializeApp();
    debugPrint('FIREBASE: initialised');
  } catch (e) {
    debugPrint('FIREBASE: initialisation failed: $e');
  }

  // Show the app IMMEDIATELY.
  runApp(const WebsApp());

  // Initialise the rest in the background.
  unawaited(_initializeBackgroundServices());
}

/// Runs after the app is visible. Nothing here blocks UI.
Future<void> _initializeBackgroundServices() async {
  // ------------------------------------------------------------
  // TRACK APP OPEN IN FIREBASE ANALYTICS
  // ------------------------------------------------------------
  try {
    await FirebaseAnalytics.instance.logAppOpen();
    debugPrint('ANALYTICS: App open logged');
  } catch (e) {
    debugPrint('ANALYTICS: initialisation failed: $e');
  }

  try {
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('NOTIF: initialisation failed: $e');
  }

  try {
    await FcmService.instance.initialize();
  } catch (e) {
    debugPrint('FCM: initialisation failed: $e');
  }

  try {
    await LocationNotificationListener.instance.initialize();
  } catch (e) {
    debugPrint('LOCATION-LISTENER: initialisation failed: $e');
  }

  try {
    await BackgroundLocationService.instance.initialize();
    debugPrint('BG-SERVICE: initialised');
  } catch (e) {
    debugPrint('BG-SERVICE: initialisation failed: $e');
  }

  try {
    await PresenceHeartbeat.instance.start();
  } catch (e) {
    debugPrint('PRESENCE: initialisation failed: $e');
  }

  debugPrint('STARTUP: all background services initialised');
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
  StreamSubscription<String>? _locationTapSubscription;

  @override
  void initState() {
    super.initState();

    _loadAppearance();
    _preloadChats();
    _loadToken();
    _listenForNotificationTaps();
    _listenForLocationTaps();
    // Shopicky "Track in Webs" links (opened once the main screen is up)
    BwLinks.instance.start(websNavigatorKey);
  }

  @override
  void dispose() {
    _localNotificationTapSubscription?.cancel();
    _fcmTapSubscription?.cancel();
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
    final data = await _contactPreloader.loadFromCacheOnly();
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
    // Taps go through the gate, which holds them until the chats
    // screen is showing (see NotificationTapGate).
    NotificationTapGate.instance.opener = _handleConversationTap;

    _localNotificationTapSubscription =
        NotificationService.instance.notificationTaps.listen(
      NotificationTapGate.instance.open,
    );

    _fcmTapSubscription = FcmService.instance.messageTaps.listen(
      NotificationTapGate.instance.open,
    );
  }

  Future<void> _handleConversationTap(String rawPayload) async {
    // Payload may be a plain conversationId, or
    // conversationId | senderId | senderName | serverMessageId.
    final parts0 = rawPayload.split('\u001F');
    final conversationId = parts0[0];
    final payloadSenderId =
        parts0.length > 1 ? int.tryParse(parts0[1]) ?? 0 : 0;
    final payloadSenderName = parts0.length > 2 ? parts0[2] : '';

    // Already looking at this chat: nothing to open.
    if (ActiveConversation.instance.isActive(conversationId)) return;

    final convParts = conversationId.split('_');
    if (convParts.length != 2) return;
    final a = int.tryParse(convParts[0]);
    final b = int.tryParse(convParts[1]);
    if (a == null || b == null) return;

    int? currentUserId;
    int? otherUserId;

    // Fast path: the notification told us who the sender is, so we can
    // open the chat immediately without waiting for anything.
    if (payloadSenderId > 0 && (a == payloadSenderId || b == payloadSenderId)) {
      otherUserId = payloadSenderId;
      currentUserId = a == payloadSenderId ? b : a;
    } else {
      final preloaded = await _waitForPreloadedChats();
      currentUserId = preloaded?.currentUserId;
      if (currentUserId == null) return;
      otherUserId = a == currentUserId ? b : a;
    }

    String name = payloadSenderName.trim().isNotEmpty
        ? payloadSenderName.trim()
        : 'Chat';
    String phoneNumber = '';
    String? profilePhotoUrl;
    var isSavedContact = true;
    String? registeredName;

    // Use already-loaded contacts if present (no network, no waiting).
    final preloaded = _preloadedChats;
    var foundInContacts = false;
    if (preloaded != null) {
      for (final entry in preloaded.matchedUsersByPhone.entries) {
        if (entry.value.id == otherUserId) {
          name = entry.value.name.trim().isNotEmpty
              ? entry.value.name.trim()
              : entry.key;
          phoneNumber = entry.value.phoneNumber;
          profilePhotoUrl = entry.value.profilePhotoUrl;
          foundInContacts = true;
          break;
        }
      }
    }

    // Not a saved contact: title with their name from the push; the
    // chat screen fills in the rest once it loads.
    if (!foundInContacts) {
      isSavedContact = false;
      registeredName =
          payloadSenderName.trim().isNotEmpty ? payloadSenderName.trim() : null;
      name = registeredName ?? 'Webs user';
    }

    final navigator = websNavigatorKey.currentState;
    final cuid = currentUserId;
    final ouid = otherUserId;
    if (navigator == null || cuid == null || ouid == null) return;

    navigator.push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          currentUserId: cuid,
          userId: ouid,
          name: name,
          phoneNumber: phoneNumber,
          profilePhotoUrl: profilePhotoUrl,
          isSavedContact: isSavedContact,
          registeredName: registeredName,
        ),
      ),
    );
  }

  Future<PreloadedChatsData?> _waitForPreloadedChats({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_preloadedChats != null) return _preloadedChats;

    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(
        const Duration(milliseconds: 150),
      );

      if (_preloadedChats != null) {
        return _preloadedChats;
      }
    }

    return _preloadedChats;
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

    NotificationTapGate.instance.open(conversationId);
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
      home: UpdateGate(child: _buildHome()),
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
        minimumDuration: const Duration(milliseconds: 3000),
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

  const WebsThemeScope({super.key,
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