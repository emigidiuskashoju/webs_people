import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../location/services/location_service.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({
    super.key,
  });

  @override
  State<RoutesScreen> createState() =>
      _RoutesScreenState();
}

class _RoutesScreenState
    extends State<RoutesScreen> {
  final LocationService _locationService =
      LocationService();

  final MapController _mapController =
      MapController();

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
      final position =
          await _locationService
              .getCurrentPosition();

      final location = LatLng(
        position.latitude,
        position.longitude,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _currentLocation =
            location;

        _accuracy =
            position.accuracy;

        _loading = false;
      });

      _mapController.move(
        location,
        16,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _errorMessage =
            e.toString();
      });
    }
  }

  void _centerOnCurrentLocation() {
    final location =
        _currentLocation;

    if (location == null) {
      return;
    }

    _mapController.move(
      location,
      16,
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Routes',
        ),
        actions: [
          IconButton(
            tooltip:
                'Refresh location',
            onPressed: _loading
                ? null
                : _loadCurrentLocation,
            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController:
                _mapController,
            options: const MapOptions(
              initialCenter:
                  LatLng(
                -6.7924,
                39.2083,
              ),
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                    'com.webs.people',
              ),

              if (_currentLocation !=
                  null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point:
                          _currentLocation!,
                      width: 60,
                      height: 60,
                      child: const Icon(
                        Icons.location_pin,
                        size: 50,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          if (_loading)
            const Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                child: Padding(
                  padding:
                      EdgeInsets.all(16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child:
                            CircularProgressIndicator(),
                      ),
                      SizedBox(
                        width: 12,
                      ),
                      Expanded(
                        child: Text(
                          'Getting your current location...',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (_errorMessage != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                child: Padding(
                  padding:
                      const EdgeInsets.all(
                    16,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      const Text(
                        'Unable to get your location',
                        style:
                            TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      Text(
                        _errorMessage!,
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      SizedBox(
                        width:
                            double.infinity,
                        child:
                            ElevatedButton(
                          onPressed:
                              _loadCurrentLocation,
                          child:
                              const Text(
                            'Try Again',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (_currentLocation !=
              null)
            Positioned(
              bottom: 24,
              right: 16,
              child: FloatingActionButton(
                onPressed:
                    _centerOnCurrentLocation,
                tooltip:
                    'My location',
                child: const Icon(
                  Icons.my_location,
                ),
              ),
            ),

          if (_currentLocation !=
                  null &&
              _accuracy != null)
            Positioned(
              bottom: 24,
              left: 16,
              child: Card(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    'Accuracy: '
                    '${_accuracy!.toStringAsFixed(1)} m',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}