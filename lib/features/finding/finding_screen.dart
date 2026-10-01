import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/webs_colors.dart';
import '../../shared/widgets/webs_background.dart';
import '../devices/services/device_heartbeat_service.dart';
import '../devices/services/device_service.dart';
import '../devices/services/device_command_service.dart';
import '../location/services/location_tracking_service.dart';

import 'models/recovery_device.dart';
import 'recovery_map.dart';
import 'services/recovery_service.dart';
import 'location_history_screen.dart';
import 'command_screen.dart';

class FindingScreen extends StatefulWidget {
  const FindingScreen({super.key});

  @override
  State<FindingScreen> createState() => _FindingScreenState();
}

class _FindingScreenState extends State<FindingScreen> {
  final RecoveryService _recoveryService = RecoveryService();
  final DeviceService _deviceService = DeviceService();
  final DeviceCommandService _commandService = DeviceCommandService();
  final DeviceHeartbeatService _heartbeatService = DeviceHeartbeatService();
  final LocationTrackingService _trackingService = LocationTrackingService();

  List<RecoveryDevice> _devices = [];
  RecoveryDevice? _selectedDevice;

  bool _loading = true;
  bool _refreshing = false;
  bool _commandLoading = false;
  String? _error;
  String? _trackingError;

  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadDevices();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _reloadRecoveryDataSilently(),
    );
  }

  Future<void> _loadDevices() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final devices = await _recoveryService.getRecoveryDevices();
      if (!mounted) return;

      RecoveryDevice? selected;
      if (_selectedDevice != null) {
        for (final device in devices) {
          if (device.id == _selectedDevice!.id) {
            selected = device;
            break;
          }
        }
      }
      selected ??= devices.isNotEmpty ? devices.first : null;

      setState(() {
        _devices = devices;
        _selectedDevice = selected;
        _loading = false;
      });

      if (selected != null) {
        await _startDeviceServices(selected);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _cleanError(e);
      });
    }
  }

  Future<void> _startDeviceServices(RecoveryDevice device) async {
    try {
      await _heartbeatService.start(deviceId: device.id);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Heartbeat could not start: ${_cleanError(e)}';
        });
      }
    }

    try {
      setState(() => _trackingError = null);
      await _trackingService.start(deviceId: device.id);
      await _reloadRecoveryDataSilently();
    } catch (e) {
      if (!mounted) return;
      setState(() => _trackingError = _cleanError(e));
    }
  }

  Future<void> _reloadRecoveryDataSilently() async {
    try {
      final devices = await _recoveryService.getRecoveryDevices();
      if (!mounted) return;

      RecoveryDevice? selected;
      if (_selectedDevice != null) {
        for (final device in devices) {
          if (device.id == _selectedDevice!.id) {
            selected = device;
            break;
          }
        }
      }
      selected ??= devices.isNotEmpty ? devices.first : null;

      setState(() {
        _devices = devices;
        _selectedDevice = selected;
      });
    } catch (_) {}
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _error = null;
    });

    try {
      final device = _selectedDevice;
      if (device != null) {
        try {
          await _deviceService.heartbeat(device.id);
        } catch (_) {}
      }

      final devices = await _recoveryService.getRecoveryDevices();
      if (!mounted) return;

      RecoveryDevice? selected;
      if (_selectedDevice != null) {
        for (final d in devices) {
          if (d.id == _selectedDevice!.id) {
            selected = d;
            break;
          }
        }
      }
      selected ??= devices.isNotEmpty ? devices.first : null;

      setState(() {
        _devices = devices;
        _selectedDevice = selected;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _cleanError(e));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _sendCommand(String command) async {
    final device = _selectedDevice;
    if (device == null) return;

    setState(() => _commandLoading = true);

    try {
      await _commandService.createCommand(
        deviceId: device.id,
        command: command,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_commandMessage(command)),
        backgroundColor: WebsColors.primaryGreen,
      ));

      await _loadDevices();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Command failed: $e'),
        backgroundColor: Colors.redAccent,
      ));
    } finally {
      if (mounted) setState(() => _commandLoading = false);
    }
  }

  String _commandMessage(String command) {
    switch (command) {
      case 'request_location':
        return 'Locate Now command sent.';
      case 'start_tracking':
        return 'Start Tracking command sent.';
      case 'stop_tracking':
        return 'Stop Tracking command sent.';
      case 'enable_lost_mode':
        return 'Lost Mode command sent.';
      case 'disable_lost_mode':
        return 'Disable Lost Mode command sent.';
      default:
        return 'Command sent.';
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: securityAppBar(title: 'Finding'),
      body: WebsBackground(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: WebsColors.primaryGreen),
      );
    }

    if (_error != null && _devices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loadDevices,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_devices.isEmpty) {
      return Center(
        child: Text(
          'No Webs devices found.',
          style: TextStyle(
            fontSize: 16,
            color: WebsColors.textLight(context),
          ),
        ),
      );
    }

    final device = _selectedDevice!;
    final topPadding =
        kToolbarHeight + MediaQuery.of(context).padding.top + 8;

    return RefreshIndicator(
      color: WebsColors.primaryGreen,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, topPadding, 16, 24),
        children: [
          _buildDeviceSelector(),
          const SizedBox(height: 16),
          _buildStatusCard(device),
          const SizedBox(height: 16),
          _buildMap(device),
          const SizedBox(height: 16),
          _buildLocationCard(device),
          if (_trackingError != null) ...[
            const SizedBox(height: 12),
            _buildTrackingError(),
          ],
          const SizedBox(height: 16),
          _buildActions(device),
          const SizedBox(height: 16),
          _buildHistoryButton(device),
          const SizedBox(height: 8),
          _buildCommandsButton(device),
        ],
      ),
    );
  }

  Widget _buildDeviceSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: WebsColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: WebsColors.shadow(context),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonFormField<RecoveryDevice>(
        initialValue: _selectedDevice,
        decoration: InputDecoration(
          labelText: 'Device',
          labelStyle: TextStyle(color: WebsColors.textLight(context)),
          prefixIcon: const Icon(
            Icons.devices,
            color: WebsColors.primaryGreen,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        dropdownColor: WebsColors.surface(context),
        isExpanded: true,
        icon: const Icon(
          Icons.keyboard_arrow_down,
          color: WebsColors.primaryGreen,
        ),
        items: _devices
            .map((device) => DropdownMenuItem<RecoveryDevice>(
                  value: device,
                  child: Text(
                    device.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: WebsColors.textDark(context)),
                  ),
                ))
            .toList(),
        onChanged: (device) async {
          if (device == null) return;
          setState(() => _selectedDevice = device);
          await _startDeviceServices(device);
        },
      ),
    );
  }

  Widget _buildStatusCard(RecoveryDevice device) {
    final online = device.isOnline;
    final recentlySeen = device.wasRecentlySeen;

    IconData icon;
    String message;
    Color cardColor;

    if (online) {
      icon = Icons.wifi;
      message = 'Device Online';
      cardColor = WebsColors.darkGreen;
    } else if (recentlySeen) {
      icon = Icons.schedule;
      message = 'Recently Seen';
      cardColor = Colors.orange.shade800;
    } else {
      icon = Icons.cloud_off;
      message = 'Device Offline';
      cardColor = Colors.grey.shade800;
    }

    if (device.isLost) cardColor = Colors.red.shade900;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: cardColor.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  device.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Last seen: ${device.lastSeenText}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                if (device.isLost)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'LOST MODE ACTIVE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // MAP CARD — with the heartbeat marker
  // ================================================================

  Widget _buildMap(RecoveryDevice device) {
    if (!device.hasLocation) {
      return Container(
        height: 320,
        decoration: BoxDecoration(
          color: WebsColors.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: WebsColors.border(context),
            width: 2,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_searching,
                size: 60,
                color: WebsColors.primaryGreen,
              ),
              const SizedBox(height: 16),
              Text(
                'Waiting for device location...',
                style: TextStyle(
                  color: WebsColors.textLight(context),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Webs is requesting a fresh GPS location.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: WebsColors.textLight(context),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 320,
        child: Stack(
          children: [
            Positioned.fill(
              child: RecoveryMap(
                latitude: device.latitude!,
                longitude: device.longitude!,
                accuracy: device.accuracy,
              ),
            ),

            // Red gradient strip along the bottom when in Lost Mode.
            if (device.isLost)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 4,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFE53935),
                        Color(0x00E53935),
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // LOCATION DETAILS CARD
  // ================================================================

  Widget _buildLocationCard(RecoveryDevice device) {
    if (!device.hasLocation) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: WebsColors.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: WebsColors.border(context),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: WebsColors.softGreen(context),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_off,
                color: WebsColors.primaryGreen,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No location yet',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: WebsColors.textDark(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Waiting for the phone to upload its GPS location.',
                    style: TextStyle(
                      color: WebsColors.textLight(context),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
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
        children: [
          _buildDetailRow(
            Icons.location_on,
            'Last known location',
            '${device.latitude}, ${device.longitude}',
          ),
          if (device.accuracy != null)
            _buildDetailRow(
              Icons.gps_fixed,
              'Accuracy',
              '${device.accuracy!.toStringAsFixed(1)} m',
            ),
          if (device.locationRecordedAt != null)
            _buildDetailRow(
              Icons.access_time,
              'Recorded',
              _formatDate(device.locationRecordedAt),
              isLast: true,
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String title,
    String subtitle, {
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: WebsColors.softGreen(context),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: WebsColors.primaryGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: WebsColors.textDark(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: WebsColors.textLight(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 70,
            endIndent: 16,
            color: WebsColors.border(context),
          ),
      ],
    );
  }

  Widget _buildTrackingError() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_disabled, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Location tracking: $_trackingError',
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // REMOTE CONTROL
  // ================================================================

  Widget _buildActions(RecoveryDevice device) {
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Remote Control',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: WebsColors.textDark(context),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _commandLoading
                ? null
                : () => _sendCommand('request_location'),
            icon: const Icon(Icons.my_location),
            label: const Text('Locate Now'),
            style: FilledButton.styleFrom(
              backgroundColor: WebsColors.primaryGreen,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _commandLoading
                ? null
                : () => _sendCommand('start_tracking'),
            icon: const Icon(
              Icons.gps_fixed,
              color: WebsColors.primaryGreen,
            ),
            label: const Text(
              'Start Tracking',
              style: TextStyle(color: WebsColors.primaryGreen),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _commandLoading
                ? null
                : () => _sendCommand('stop_tracking'),
            icon: Icon(
              Icons.gps_off,
              color: WebsColors.textLight(context),
            ),
            label: Text(
              'Stop Tracking',
              style: TextStyle(color: WebsColors.textLight(context)),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _commandLoading
                ? null
                : () => _sendCommand(
                      device.isLost
                          ? 'disable_lost_mode'
                          : 'enable_lost_mode',
                    ),
            icon: const Icon(
              Icons.warning_amber,
              color: Colors.red,
            ),
            label: Text(
              device.isLost ? 'Disable Lost Mode' : 'Enable Lost Mode',
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryButton(RecoveryDevice device) {
    return OutlinedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LocationHistoryScreen(device: device),
          ),
        );
      },
      icon: const Icon(
        Icons.timeline,
        color: WebsColors.primaryGreen,
      ),
      label: const Text(
        'Location History',
        style: TextStyle(
          color: WebsColors.primaryGreen,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCommandsButton(RecoveryDevice device) {
    return OutlinedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CommandScreen(device: device),
          ),
        );
      },
      icon: const Icon(
        Icons.terminal,
        color: WebsColors.primaryGreen,
      ),
      label: const Text(
        'Command Status',
        style: TextStyle(
          color: WebsColors.primaryGreen,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}:'
        '${local.second.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _heartbeatService.dispose();
    _trackingService.stop();
    super.dispose();
  }
}