import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteService {
  Future<List<LatLng>> getDrivingRoute({
    required LatLng start,
    required LatLng destination,
  }) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${start.longitude},${start.latitude};'
      '${destination.longitude},${destination.latitude}'
      '?overview=full&geometries=geojson',
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Unable to calculate route',
      );
    }

    final data =
        jsonDecode(response.body)
            as Map<String, dynamic>;

    if (data['code'] != 'Ok') {
      throw Exception(
        'No route was found',
      );
    }

    final routes =
        data['routes'] as List<dynamic>;

    if (routes.isEmpty) {
      throw Exception(
        'No route was found',
      );
    }

    final route =
        routes.first as Map<String, dynamic>;

    final geometry =
        route['geometry']
            as Map<String, dynamic>;

    final coordinates =
        geometry['coordinates']
            as List<dynamic>;

    return coordinates.map((coordinate) {
      final point =
          coordinate as List<dynamic>;

      return LatLng(
        (point[1] as num).toDouble(),
        (point[0] as num).toDouble(),
      );
    }).toList();
  }
}