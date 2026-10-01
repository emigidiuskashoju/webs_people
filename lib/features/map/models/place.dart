import 'package:latlong2/latlong.dart';

class Place {
  final String id;
  final String name;
  final String displayName;
  final LatLng position;

  const Place({
    required this.id,
    required this.name,
    required this.displayName,
    required this.position,
  });

  factory Place.fromNominatim(Map<String, dynamic> json) {
    final lat = double.tryParse(json['lat']?.toString() ?? '') ?? 0.0;
    final lon = double.tryParse(json['lon']?.toString() ?? '') ?? 0.0;

    final display = json['display_name']?.toString() ?? '';
    final rawName = json['name']?.toString() ?? '';

    final name = rawName.isNotEmpty
        ? rawName
        : (display.isNotEmpty ? display.split(',').first.trim() : 'Unknown place');

    return Place(
      id: json['place_id']?.toString() ?? '$lat,$lon',
      name: name,
      displayName: display,
      position: LatLng(lat, lon),
    );
  }
}