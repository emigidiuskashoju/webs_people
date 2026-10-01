import 'package:latlong2/latlong.dart';

class CustomRoutePoint {
  final double latitude;
  final double longitude;
  final int order;

  const CustomRoutePoint({
    required this.latitude,
    required this.longitude,
    required this.order,
  });

  LatLng get position => LatLng(
        latitude,
        longitude,
      );

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'order': order,
    };
  }

  factory CustomRoutePoint.fromJson(
    Map<String, dynamic> json,
  ) {
    return CustomRoutePoint(
      latitude: _toDouble(json['latitude']) ?? 0,
      longitude: _toDouble(json['longitude']) ?? 0,
      order: _toInt(json['order']) ?? 0,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ?? '',
    );
  }

  static int? _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(
      value?.toString() ?? '',
    );
  }
}

class CustomRoute {
  final int id;
  final int locationRequestId;
  final int ownerId;
  final int recipientId;
  final List<CustomRoutePoint> points;
  final double totalDistanceMeters;
  final DateTime? createdAt;

  const CustomRoute({
    required this.id,
    required this.locationRequestId,
    required this.ownerId,
    required this.recipientId,
    required this.points,
    required this.totalDistanceMeters,
    required this.createdAt,
  });

  List<LatLng> get positions {
    return points
        .map((point) => point.position)
        .toList();
  }

  factory CustomRoute.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawPoints = json['points'];

    final points = rawPoints is List
        ? rawPoints
            .whereType<Map>()
            .map(
              (item) => CustomRoutePoint.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList()
        : <CustomRoutePoint>[];

    points.sort(
      (a, b) => a.order.compareTo(b.order),
    );

    return CustomRoute(
      id: _toInt(json['id']) ?? 0,
      locationRequestId:
          _toInt(json['location_request_id']) ?? 0,
      ownerId: _toInt(json['owner_id']) ?? 0,
      recipientId:
          _toInt(json['recipient_id']) ?? 0,
      points: points,
      totalDistanceMeters:
          _toDouble(json['total_distance_meters']) ?? 0,
      createdAt: _toDateTime(
        json['created_at'],
      ),
    );
  }

  static int? _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(
      value?.toString() ?? '',
    );
  }

  static double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ?? '',
    );
  }

  static DateTime? _toDateTime(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(
      value.toString(),
    );
  }
}