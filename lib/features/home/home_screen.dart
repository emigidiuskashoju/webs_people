import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../core/theme/webs_colors.dart';
import '../../shared/widgets/webs_background.dart';
import '../auth/services/auth_service.dart';
import '../devices/services/device_service.dart';
import '../main/main_navigation_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final DeviceService _deviceService = DeviceService();

  Map<String, dynamic>? _user;
  List<Map<String, dynamic>> _devices = [];
  bool _loading = true;
  bool _deviceRegistrationRunning = false;
  String? _errorMessage;
  String? _deviceErrorMessage;

  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadHome();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadDevices(),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadHome() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
        _deviceErrorMessage = null;
      });
    }

    try {
      final userResponse = await _authService.me();
      if (!mounted) return;

      setState(() {
        _user = _extractUser(userResponse);
      });

      await _ensureDeviceRegistered();
      await _loadDevices();

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = _cleanError(e);
      });
    }
  }

  Map<String, dynamic> _extractUser(Map<String, dynamic> response) {
    final user = response['user'];
    if (user is Map) return Map<String, dynamic>.from(user);
    return response;
  }

  Future<void> _loadDevices() async {
    try {
      final devices = await _deviceService.getDevices();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _deviceErrorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _devices = [];
        _deviceErrorMessage = _cleanError(e);
      });
    }
  }

  Future<void> _ensureDeviceRegistered() async {
    if (_deviceRegistrationRunning) return;
    _deviceRegistrationRunning = true;
    try {
      await _deviceService.registerDevice();
    } catch (e) {
      if (!mounted) return;
      setState(() => _deviceErrorMessage = _cleanError(e));
    } finally {
      _deviceRegistrationRunning = false;
    }
  }

  Future<void> _refresh() async {
    await _loadHome();
  }

  void _goBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const MainNavigationScreen(),
        ),
        (route) => false,
      );
    }
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('ApiException: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final name = _user?['name']?.toString();

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: securityAppBar(
        title: 'Webs Security',
        onBack: _goBack,
      ),
      body: WebsBackground(
        child: _loading && _user == null
            ? const Center(
                child: CircularProgressIndicator(
                  color: WebsColors.primaryGreen,
                ),
              )
            : RefreshIndicator(
                color: WebsColors.primaryGreen,
                onRefresh: _refresh,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    kToolbarHeight + MediaQuery.of(context).padding.top + 12,
                    20,
                    20,
                  ),
                  children: [
                    if (_errorMessage != null) _buildErrorCard(),
                    _buildWelcome(name),
                    const SizedBox(height: 24),
                    _buildProtectionCard(),
                    const SizedBox(height: 16),
                    _buildDevicesCard(),
                    const SizedBox(height: 16),
                    _buildRecoveryCard(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome(String? name) {
    final displayName =
        name != null && name.trim().isNotEmpty ? name.trim() : 'User';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, $displayName',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: WebsColors.textDark(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Protect and find your devices.',
                style: TextStyle(
                  fontSize: 16,
                  color: WebsColors.textLight(context),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: WebsColors.softGreen(context),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.shield,
            color: WebsColors.primaryGreen,
            size: 28,
          ),
        ),
      ],
    );
  }

  Widget _buildProtectionCard() {
    final deviceCount = _devices.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: WebsColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: WebsColors.shadow(context),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: WebsColors.border(context), width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: WebsColors.softGreen(context),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield,
              size: 36,
              color: WebsColors.primaryGreen,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Protection Active',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: WebsColors.textDark(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$deviceCount device(s) registered',
                  style: TextStyle(
                    fontSize: 14,
                    color: WebsColors.textLight(context),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: WebsColors.textLight(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: WebsColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: WebsColors.shadow(context),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Devices',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: WebsColors.textDark(context),
                ),
              ),
              const Text(
                'View All',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: WebsColors.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_deviceErrorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _deviceErrorMessage!,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 13,
                ),
              ),
            ),
          if (_devices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No devices registered yet.',
                  style: TextStyle(color: WebsColors.textLight(context)),
                ),
              ),
            )
          else
            ..._devices.take(3).map((device) {
              final name = device['name']?.toString() ?? 'Webs Device';
              final isLost = device['is_lost'] == true;

              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isLost
                            ? const Color(0xFFFFEBEE)
                            : WebsColors.softGreen(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.phone_android,
                        color: isLost
                            ? Colors.red
                            : WebsColors.primaryGreen,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: WebsColors.textDark(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isLost ? 'LOST MODE' : 'Protected',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isLost
                                  ? Colors.red
                                  : WebsColors.accentGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isLost)
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red,
                      )
                    else
                      const Icon(
                        Icons.check_circle,
                        color: WebsColors.accentGreen,
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRecoveryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: WebsColors.darkGreen,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: WebsColors.darkGreen.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Recovery',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Find a lost device, view its location, and control Lost Mode.',
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, WebsRoutes.finding);
            },
            icon: const Icon(Icons.radar, color: WebsColors.darkGreen),
            label: const Text(
              'Find Device',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: WebsColors.darkGreen,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: WebsColors.accentGreen,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}