import 'package:flutter/material.dart';

import '../../core/theme/webs_colors.dart';
import '../../shared/widgets/webs_background.dart';
import 'services/device_service.dart';
import 'device_details_screen.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final DeviceService _deviceService = DeviceService();
  List<Map<String, dynamic>> _devices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _loading = true);
    try {
      final devices = await _deviceService.getDevices();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Unable to load devices: $e'),
        backgroundColor: Colors.redAccent,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: securityAppBar(title: 'My Devices'),
      body: WebsBackground(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: WebsColors.primaryGreen,
                ),
              )
            : RefreshIndicator(
                color: WebsColors.primaryGreen,
                onRefresh: _loadDevices,
                child: _devices.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
                        itemCount: _devices.length,
                        itemBuilder: (context, i) => _buildDevice(_devices[i]),
                      ),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Icon(
          Icons.devices_other,
          size: 80,
          color: WebsColors.softGreen(context),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'No devices registered.',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: WebsColors.textLight(context),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Pull down to refresh.',
            style: TextStyle(
              fontSize: 14,
              color: WebsColors.textLight(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDevice(Map<String, dynamic> data) {
    final id = int.parse(data['id'].toString());
    final name = data['name']?.toString() ?? 'Webs Device';
    final platform = data['platform']?.toString() ?? 'unknown';
    final lost = data['is_lost'] == true;

    IconData platformIcon = Icons.devices;
    if (platform == 'android') platformIcon = Icons.android;
    else if (platform == 'ios') platformIcon = Icons.phone_iphone;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          color: lost
              ? Colors.red.withValues(alpha: 0.2)
              : WebsColors.border(context),
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DeviceDetailsScreen(
                deviceId: id,
                deviceName: name,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: lost
                        ? const Color(0xFFFFEBEE)
                        : WebsColors.softGreen(context),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    platformIcon,
                    color: lost ? Colors.red : WebsColors.primaryGreen,
                    size: 28,
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
                          fontWeight: FontWeight.bold,
                          color: WebsColors.textDark(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: lost
                                  ? const Color(0xFFFFEBEE)
                                  : WebsColors.softGreen(context),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              lost ? 'LOST MODE' : 'PROTECTED',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: lost
                                    ? Colors.red
                                    : WebsColors.accentGreen,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            platform.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: WebsColors.textLight(context),
                            ),
                          ),
                        ],
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
          ),
        ),
      ),
    );
  }
}