import 'package:flutter/material.dart';

import 'services/device_service.dart';
import '../finding/finding_screen.dart';
import 'device_health_screen.dart';

class DeviceDetailsScreen
    extends StatefulWidget {
  final int deviceId;
  final String deviceName;

  const DeviceDetailsScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<DeviceDetailsScreen>
      createState() =>
          _DeviceDetailsScreenState();
}

class _DeviceDetailsScreenState
    extends State<DeviceDetailsScreen> {
  final DeviceService
      _deviceService =
      DeviceService();

  Map<String, dynamic>? _device;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDevice();
  }

  Future<void> _loadDevice() async {
    setState(() {
      _loading = true;
    });

    try {
      final devices =
          await _deviceService
              .getDevices();

      Map<String, dynamic>?
          found;

      for (final device
          in devices) {
        if (int.parse(
                device['id'].toString()) ==
            widget.deviceId) {
          found = device;
          break;
        }
      }

      if (!mounted) return;

      setState(() {
        _device = found;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.deviceName,
        ),
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final device =
        _device;

    if (device == null) {
      return const Center(
        child: Text(
          'Device not found.',
        ),
      );
    }

    final lost =
        device['is_lost'] == true;

    final lastSeen =
        device['last_seen_at'];

    return ListView(
      padding:
          const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading:
                const Icon(
              Icons.devices,
              size: 40,
            ),
            title:
                Text(widget.deviceName),
            subtitle: Text(
              lost
                  ? 'LOST MODE'
                  : 'Protected',
            ),
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        Card(
          child: Column(
            children: [
              ListTile(
                leading:
                    const Icon(
                  Icons.wifi,
                ),
                title:
                    const Text(
                  'Last heartbeat',
                ),
                subtitle:
                    Text(
                  lastSeen?.toString() ??
                      'Never',
                ),
              ),
              ListTile(
                leading:
                    const Icon(
                  Icons.location_on,
                ),
                title:
                    const Text(
                  'Location',
                ),
                subtitle:
                    const Text(
                  'Controlled by Webs location service',
                ),
              ),
              ListTile(
                leading:
                    const Icon(
                  Icons.security,
                ),
                title:
                    const Text(
                  'Security',
                ),
                subtitle:
                    const Text(
                  'Device identity protected',
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        FilledButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const FindingScreen(),
              ),
            );
          },
          icon:
              const Icon(
            Icons.radar,
          ),
          label:
              const Text(
            'Find This Device',
          ),
        ),

        const SizedBox(
          height: 8,
        ),

        OutlinedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    DeviceHealthScreen(
                  deviceId:
                      widget.deviceId,
                  deviceName:
                      widget.deviceName,
                ),
              ),
            );
          },
          icon:
              const Icon(
            Icons.health_and_safety,
          ),
          label:
              const Text(
            'Device Health',
          ),
        ),
      ],
    );
  }
}