import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/auth_storage.dart';
import '../../../core/theme/webs_colors.dart';
import '../../map/widgets/photo_marker.dart';
import '../models/place.dart';

class CreatePlaceScreen extends StatefulWidget {
  const CreatePlaceScreen({super.key});

  @override
  State<CreatePlaceScreen> createState() => _CreatePlaceScreenState();
}

class _CreatePlaceScreenState extends State<CreatePlaceScreen> {
  final TextEditingController _nameController = TextEditingController();
  final MapController _mapController = MapController();

  final ImagePicker _picker = ImagePicker();

  LatLng? _selectedLocation;
  bool _loadingLocation = true;
  bool _submitting = false;
  Place? _createdPlace;

  XFile? _photoFile;
  XFile? _logoFile;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      
      setState(() {
        _selectedLocation = LatLng(pos.latitude, pos.longitude);
        _loadingLocation = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(_selectedLocation!, 16);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingLocation = false);
    }
  }

  Future<void> _pickImage(bool isLogo) async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (file == null) return;
    setState(() {
      if (isLogo) {
        _logoFile = file;
      } else {
        _photoFile = file;
      }
    });
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a name')));
      return;
    }
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a location on the map')));
      return;
    }

    setState(() => _submitting = true);

    try {
      final token = await AuthStorage().getToken();
      if (token == null) throw Exception("Not logged in");

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiEndpoints.baseUrl}/places'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      request.fields['name'] = _nameController.text.trim();
      request.fields['latitude'] = _selectedLocation!.latitude.toString();
      request.fields['longitude'] = _selectedLocation!.longitude.toString();

      if (_photoFile != null) {
        request.files.add(await http.MultipartFile.fromPath('photo', _photoFile!.path));
      }
      if (_logoFile != null) {
        request.files.add(await http.MultipartFile.fromPath('logo', _logoFile!.path));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final place = Place.fromJson(data['data'], data['share_link']);
        setState(() {
          _createdPlace = place;
          _submitting = false;
        });
      } else {
        throw Exception('Failed to save: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _copyLink() {
    if (_createdPlace == null) return;
    Clipboard.setData(ClipboardData(text: _createdPlace!.shareLink));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied to clipboard!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Business Location'),
      ),
      body: _createdPlace != null
          ? _buildSuccessView()
          : _loadingLocation
              ? const Center(child: CircularProgressIndicator(color: WebsColors.primaryGreen))
              : _buildForm(),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: WebsColors.primaryGreen, size: 80),
            const SizedBox(height: 16),
            const Text('Location Registered!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Share this link with your customers so they can find you:', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: WebsColors.softGreen(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: WebsColors.primaryGreen),
              ),
              child: SelectableText(
                _createdPlace!.shareLink,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: WebsColors.primaryGreen),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse(_createdPlace!.shareLink)),
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text('Test Link'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _copyLink,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Link'),
                    style: FilledButton.styleFrom(backgroundColor: WebsColors.primaryGreen),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            TextButton(
              onPressed: () {
                setState(() {
                  _createdPlace = null;
                  _nameController.clear();
                  _photoFile = null;
                  _logoFile = null;
                });
              },
              child: const Text('Register another location'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        Expanded(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation ?? const LatLng(-6.7924, 39.2083),
              initialZoom: 16,
              onTap: (tapPosition, point) {
                setState(() => _selectedLocation = point);
              },
            ),
            children: [
              // Use your tile layer here
              // MapboxTileLayer.forStyle(MapStyleKind.streets),
              
              if (_selectedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation!,
                      width: 50,
                      height: 65,
                      alignment: Alignment.topCenter,
                      child: PhotoMarker(
                        photoUrl: _logoFile?.path,
                        fallbackInitial: '📍',
                        ringColor: WebsColors.primaryGreen,
                        fillColor: WebsColors.softGreen(context),
                        size: 44,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: WebsColors.surface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tap the map to place the pin exactly on your shop.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Business Name (e.g. Ubepari Store)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(false),
                      icon: const Icon(Icons.photo),
                      label: Text(_photoFile == null ? 'Add Photo' : 'Photo Selected'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(true),
                      icon: const Icon(Icons.image),
                      label: Text(_logoFile == null ? 'Add Logo' : 'Logo Selected'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(backgroundColor: WebsColors.primaryGreen),
                  child: _submitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Generate Location Link', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}