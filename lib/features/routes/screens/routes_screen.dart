import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '/core/theme/webs_colors.dart';
import '../../location/services/location_service.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  final LocationService _locationService = LocationService();
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  double? _accuracy;
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }
    try {
      final position = await _locationService.getCurrentPosition();
      final location = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() {
        _currentLocation = location;
        _accuracy = position.accuracy;
        _loading = false;
      });
      if (_currentLocation != null) {
        _mapController.move(_currentLocation!, 16);
      } else {
        _loadCurrentLocation();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _centerOnCurrentLocation() {
    final location = _currentLocation;
    if (location == null) return;
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 16);
    } else {
      _loadCurrentLocation();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Routes'),
        actions: [
          IconButton(
            tooltip: 'Refresh location',
            onPressed: _loading ? null : _loadCurrentLocation,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(-6.7924, 39.2083),
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.webs.people',
              ),
              if (_currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation!,
                      width: 60,
                      height: 60,
                      child: const Icon(
                        Icons.location_pin,
                        size: 50,
                        color: WebsColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (_loading)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: WebsColors.surface(context),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: WebsColors.shadow(context),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: WebsColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Getting your current location...',
                      style: TextStyle(color: WebsColors.textDark(context)),
                    ),
                  ],
                ),
              ),
            ),
          if (_errorMessage != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: WebsColors.surface(context),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: WebsColors.shadow(context),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unable to get your location',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: WebsColors.textDark(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: WebsColors.textLight(context)),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _loadCurrentLocation,
                        style: FilledButton.styleFrom(
                          backgroundColor: WebsColors.primaryGreen,
                        ),
                        child: const Text('Try Again'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_currentLocation != null)
            Positioned(
              bottom: 24,
              right: 16,
              child: FloatingActionButton(
                onPressed: _centerOnCurrentLocation,
                tooltip: 'My location',
                backgroundColor: WebsColors.primaryGreen,
                foregroundColor: Colors.white,
                child: const Icon(Icons.my_location),
              ),
            ),
          if (_currentLocation != null && _accuracy != null)
            Positioned(
              bottom: 24,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: WebsColors.surface(context),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: WebsColors.shadow(context),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'Accuracy: ${_accuracy!.toStringAsFixed(1)} m',
                  style: TextStyle(color: WebsColors.textDark(context)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}