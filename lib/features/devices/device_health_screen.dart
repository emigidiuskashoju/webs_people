import 'package:flutter/material.dart';

import 'services/device_health_service.dart';

class DeviceHealthScreen
    extends StatefulWidget {
  final int deviceId;
  final String deviceName;

  const DeviceHealthScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<DeviceHealthScreen>
      createState() =>
          _DeviceHealthScreenState();
}

class _DeviceHealthScreenState
    extends State<DeviceHealthScreen> {
  final DeviceHealthService
      _healthService =
      DeviceHealthService();

  Map<String, dynamic>?
      _health;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHealth();
  }

  Future<void> _loadHealth() async {
    setState(() {
      _loading = true;
    });

    try {
      final health =
          await _healthService
              .getHealth();

      if (!mounted) return;

      setState(() {
        _health = health;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Unable to read device health: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.deviceName),
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh:
                  _loadHealth,
              child: ListView(
                padding:
                    const EdgeInsets.all(16),
                children: [
                  _healthTile(
                    Icons.battery_full,
                    'Battery',
                    '${_health?['battery_level'] ?? '--'}%',
                  ),
                  _healthTile(
                    Icons.power,
                    'Charging',
                    _health?['is_charging'] == true
                        ? 'Yes'
                        : 'No',
                  ),
                  _healthTile(
                    Icons.info_outline,
                    'Device',
                    widget.deviceName,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _healthTile(
    IconData icon,
    String title,
    String value,
  ) {
    return Card(
      child: ListTile(
        leading:
            Icon(icon),
        title: Text(title),
        subtitle:
            Text(value),
      ),
    );
  }
}