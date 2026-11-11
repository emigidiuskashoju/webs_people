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

/// A full plan for one destination: the best route plus up to two
/// alternative routes to show faintly behind it.
class RoutePlan {
  final RouteResult main;
  final List<List<LatLng>> alternatives;

  const RoutePlan({
    required this.main,
    required this.alternatives,
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

  /// Fetches the best route plus up to two alternatives in one call.
  Future<RoutePlan?> fetchRoutes({
    required LatLng from,
    required LatLng to,
  }) async {
    final uri = Uri.parse(
      '$_osrmBase/'
      '${from.longitude},${from.latitude};'
      '${to.longitude},${to.latitude}'
      '?overview=full&geometries=geojson&steps=false&alternatives=3',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body);
    final routes = data['routes'];
    if (routes is! List || routes.isEmpty) return null;

    List<LatLng> parse(dynamic route) {
      final coords = route['geometry']?['coordinates'];
      if (coords is! List) return <LatLng>[];
      return coords
          .whereType<List>()
          .where((item) => item.length >= 2)
          .map((item) => LatLng(
                (item[1] as num).toDouble(),
                (item[0] as num).toDouble(),
              ))
          .toList();
    }

    final first = routes.first;
    final main = RouteResult(
      geometry: parse(first),
      distanceMeters: (first['distance'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: (first['duration'] as num?)?.toDouble() ?? 0.0,
    );
    if (main.geometry.length < 2) return null;

    // Up to two alternatives (OSRM returns the best first).
    final alternatives = <List<LatLng>>[];
    for (final route in routes.skip(1).take(2)) {
      final geo = parse(route);
      if (geo.length >= 2) alternatives.add(geo);
    }

    return RoutePlan(main: main, alternatives: alternatives);
  }
}