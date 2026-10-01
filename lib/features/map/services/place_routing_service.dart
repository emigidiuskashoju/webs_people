import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteResult {
  final List<LatLng> geometry;
  final double distanceMeters;
  final double durationSeconds;

  const RouteResult({
    required this.geometry,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}

class PlaceRoutingService {
  PlaceRoutingService();

  static const String _osrmBase =
      'https://router.project-osrm.org/route/v1/driving';

  Future<RouteResult?> fetchRoute({
    required LatLng from,
    required LatLng to,
  }) async {
    final uri = Uri.parse(
      '$_osrmBase/'
      '${from.longitude},${from.latitude};'
      '${to.longitude},${to.latitude}'
      '?overview=full&geometries=geojson&steps=false',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body);
    final routes = data['routes'];
    if (routes is! List || routes.isEmpty) return null;

    final first = routes.first;
    final geometry = first['geometry'];
    final coordinates = geometry['coordinates'];
    if (coordinates is! List) return null;

    final points = coordinates
        .whereType<List>()
        .where((item) => item.length >= 2)
        .map((item) => LatLng(
              (item[1] as num).toDouble(),
              (item[0] as num).toDouble(),
            ))
        .toList();

    final distance = (first['distance'] as num?)?.toDouble() ?? 0.0;
    final duration = (first['duration'] as num?)?.toDouble() ?? 0.0;

    return RouteResult(
      geometry: points,
      distanceMeters: distance,
      durationSeconds: duration,
    );
  }
}