import 'package:flutter/material.dart';

import '../../core/theme/webs_colors.dart';
import '../../shared/widgets/webs_background.dart';
import 'services/locations_service.dart';
import 'services/location_queue_service.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final LocationsService _locationService = LocationsService();
  final LocationQueueService _queueService = LocationQueueService();

  bool _loading = true;
  String _gpsStatus = 'Checking...';
  String _coordinates = 'Unavailable';
  String _accuracy = 'Unavailable';
  int _pending = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final allowed = await _locationService.ensurePermission();

      if (!allowed) {
        setState(() {
          _gpsStatus = 'Disabled';
          _loading = false;
        });
        return;
      }

      final location = await _locationService.getCurrentLocation();
      final pending = await _queueService.count();

      if (!mounted) return;

      setState(() {
        _gpsStatus = 'Available';
        _coordinates = '${location.latitude}, ${location.longitude}';
        _accuracy = '${location.accuracy.toStringAsFixed(1)} m';
        _pending = pending;
        _loading = false;
      });
    } catch (e) {
      final pending = await _queueService.count();
      if (!mounted) return;
      setState(() {
        _gpsStatus = 'Unavailable';
        _coordinates = 'Unavailable';
        _accuracy = 'Unavailable';
        _pending = pending;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: securityAppBar(title: 'Location'),
      body: WebsBackground(
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: WebsColors.primaryGreen,
                  ),
                )
              : RefreshIndicator(
                  color: WebsColors.primaryGreen,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
                    children: [
                      _statusCard(),
                      const SizedBox(height: 12),
                      _infoTile(
                        Icons.gps_fixed,
                        'GPS',
                        _gpsStatus,
                      ),
                      _infoTile(
                        Icons.location_on,
                        'Coordinates',
                        _coordinates,
                      ),
                      _infoTile(
                        Icons.gps_fixed,
                        'Accuracy',
                        _accuracy,
                      ),
                      _infoTile(
                        Icons.cloud_upload,
                        'Pending uploads',
                        '$_pending',
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: WebsColors.surface(context),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: WebsColors.border(context),
                            width: 2,
                          ),
                        ),
                        child: Text(
                          'If this phone loses Internet, '
                          'Webs can continue collecting '
                          'GPS locations locally. '
                          'They will be uploaded when '
                          'Internet connectivity returns.',
                          style: TextStyle(
                            color: WebsColors.textLight(context),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _statusCard() {
    final available = _gpsStatus == 'Available';

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
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: WebsColors.softGreen(context),
              shape: BoxShape.circle,
            ),
            child: Icon(
              available ? Icons.gps_fixed : Icons.gps_off,
              size: 50,
              color: WebsColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'GPS $_gpsStatus',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: WebsColors.textDark(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String title, String value) {
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