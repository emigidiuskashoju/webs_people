import 'package:flutter/material.dart';

import '../../core/theme/webs_colors.dart';
import '../../shared/widgets/webs_background.dart';
import '../devices/services/device_service.dart';
import '../location/services/location_tracking_service.dart';

class LostModeScreen extends StatefulWidget {
  const LostModeScreen({super.key});

  @override
  State<LostModeScreen> createState() => _LostModeScreenState();
}

class _LostModeScreenState extends State<LostModeScreen> {
  final DeviceService _deviceService = DeviceService();
  final LocationTrackingService _trackingService = LocationTrackingService();

  bool _loading = false;
  int? _deviceId;
  bool _lostMode = false;

  @override
  void initState() {
    super.initState();
    _loadDevice();
  }

  Future<void> _loadDevice() async {
    try {
      final devices = await _deviceService.getDevices();
      if (devices.isEmpty) return;

      final device = devices.first;
      if (!mounted) return;

      setState(() {
        _deviceId = int.parse(device['id'].toString());
        _lostMode = device['is_lost'] == true;
      });
    } catch (_) {}
  }

  Future<void> _toggleLostMode() async {
    final id = _deviceId;
    if (id == null) return;

    setState(() => _loading = true);

    try {
      if (_lostMode) {
        await _deviceService.disableLostMode(id);
        await _trackingService.stop();
      } else {
        await _deviceService.enableLostMode(id);
        await _trackingService.start(deviceId: id);
      }

      if (!mounted) return;

      setState(() => _lostMode = !_lostMode);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _lostMode ? 'Lost Mode enabled.' : 'Lost Mode disabled.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lost Mode error: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: securityAppBar(title: 'Lost Mode'),
      body: WebsBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
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
                  border: Border.all(
                    color: WebsColors.border(context),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _lostMode
                            ? const Color(0xFFFFEBEE)
                            : WebsColors.softGreen(context),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _lostMode ? Icons.warning : Icons.shield,
                        size: 56,
                        color: _lostMode
                            ? Colors.red
                            : WebsColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _lostMode ? 'LOST MODE ACTIVE' : 'Lost Mode Off',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _lostMode
                            ? Colors.red
                            : WebsColors.textDark(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _lostMode
                          ? 'Webs is monitoring this device.'
                          : 'This device is operating normally.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: WebsColors.textLight(context)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _statusTile(
                Icons.gps_fixed,
                'Location tracking',
                _trackingService.isTracking ? 'Active' : 'Inactive',
              ),
              _statusTile(
                Icons.cloud_off,
                'Offline support',
                'Location queue enabled',
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loading ? null : _toggleLostMode,
                icon: Icon(_lostMode ? Icons.stop : Icons.warning),
                label: Text(
                  _lostMode ? 'Disable Lost Mode' : 'Enable Lost Mode',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _lostMode
                      ? Colors.red
                      : WebsColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusTile(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: WebsColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WebsColors.border(context), width: 2),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: WebsColors.softGreen(context),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: WebsColors.primaryGreen, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: WebsColors.textDark(context),
          ),
        ),
        subtitle: Text(
          value,
          style: TextStyle(color: WebsColors.textLight(context)),
        ),
      ),
    );
  }
}