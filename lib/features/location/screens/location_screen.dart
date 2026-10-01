import 'package:flutter/material.dart';

import '/core/theme/webs_colors.dart';
import '/core/widgets/webs_background.dart';
import '../services/location_api_service.dart';
import '../services/location_service.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final LocationService _locationService = LocationService();
  final LocationApiService _apiService = LocationApiService();

  bool _sharing = false;
  bool _loading = false;
  String _message = 'Location sharing is off.';

  Future<void> _toggleSharing() async {
    setState(() => _loading = true);
    try {
      if (_sharing) {
        await _apiService.stopSharing();
        if (!mounted) return;
        setState(() {
          _sharing = false;
          _message = 'Location sharing is off.';
        });
      } else {
        final position = await _locationService.getCurrentPosition();
        await _apiService.shareLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
        );
        if (!mounted) return;
        setState(() {
          _sharing = true;
          _message = 'Your current location is being shared.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Location')),
      body: WebsBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: WebsColors.softGreen(context),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _sharing ? Icons.location_on : Icons.location_off,
                      size: 64,
                      color: WebsColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: WebsColors.textDark(context),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _loading ? null : _toggleSharing,
                      style: FilledButton.styleFrom(
                        backgroundColor: WebsColors.primaryGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _loading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : Text(
                              _sharing ? 'Stop Sharing' : 'Share My Location',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}