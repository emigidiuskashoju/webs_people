import 'package:latlong2/latlong.dart';

class RoutePoint {
  final String id;
  final LatLng position;
  final int order;

  const RoutePoint({
    required this.id,
    required this.position,
    required this.order,
  });
}