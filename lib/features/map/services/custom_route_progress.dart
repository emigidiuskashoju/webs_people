import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

class CustomRouteProgress {
  final List<LatLng> remainingPoints;
  final double remainingDistanceMeters;
  final double travelledDistanceMeters;

  const CustomRouteProgress({
    required this.remainingPoints,
    required this.remainingDistanceMeters,
    required this.travelledDistanceMeters,
  });

  bool get isComplete =>
      remainingDistanceMeters <= 1;
}

class CustomRouteProgressCalculator {
  static const double _completionDistanceMeters = 25;

  static CustomRouteProgress calculate({
    required LatLng currentLocation,
    required List<LatLng> route,
  }) {
    if (route.length < 2) {
      return const CustomRouteProgress(
        remainingPoints: [],
        remainingDistanceMeters: 0,
        travelledDistanceMeters: 0,
      );
    }

    final segmentDistances = <double>[];

    double totalDistance = 0;

    for (var i = 0; i < route.length - 1; i++) {
      final distance = _distance(
        route[i],
        route[i + 1],
      );

      segmentDistances.add(distance);
      totalDistance += distance;
    }

    var bestDistance = double.infinity;
    var bestSegmentIndex = 0;
    var bestT = 0.0;

    for (var i = 0; i < route.length - 1; i++) {
      final projection = _nearestPointOnSegment(
        currentLocation,
        route[i],
        route[i + 1],
      );

      if (projection.distanceToPoint <
          bestDistance) {
        bestDistance =
            projection.distanceToPoint;

        bestSegmentIndex = i;
        bestT = projection.t;
      }
    }

    double travelledDistance = 0;

    for (var i = 0; i < bestSegmentIndex; i++) {
      travelledDistance +=
          segmentDistances[i];
    }

    travelledDistance +=
        segmentDistances[bestSegmentIndex] *
            bestT;

    if (bestDistance >
        _completionDistanceMeters) {
      return CustomRouteProgress(
        remainingPoints: route,
        remainingDistanceMeters:
            totalDistance,
        travelledDistanceMeters: 0.0,
      );
    }

    final remainingDistance =
        math.max(
      0.0,
      totalDistance - travelledDistance,
    );

    final projected = _nearestPointOnSegment(
      currentLocation,
      route[bestSegmentIndex],
      route[bestSegmentIndex + 1],
    ).point;

    final remaining = <LatLng>[
      projected,
      ...route.skip(bestSegmentIndex + 1),
    ];

    return CustomRouteProgress(
      remainingPoints: remaining,
      remainingDistanceMeters:
          remainingDistance,
      travelledDistanceMeters:
          travelledDistance,
    );
  }

  static double _distance(
    LatLng a,
    LatLng b,
  ) {
    const distance = Distance();

    return distance.as(
      LengthUnit.Meter,
      a,
      b,
    );
  }

  static _Projection _nearestPointOnSegment(
    LatLng point,
    LatLng a,
    LatLng b,
  ) {
    final latRadians =
        point.latitude * math.pi / 180;

    final scaleX =
        111320 * math.cos(latRadians);

    final scaleY = 110540.0;

    final ax = a.longitude * scaleX;
    final ay = a.latitude * scaleY;

    final bx = b.longitude * scaleX;
    final by = b.latitude * scaleY;

    final px = point.longitude * scaleX;
    final py = point.latitude * scaleY;

    final dx = bx - ax;
    final dy = by - ay;

    final lengthSquared =
        dx * dx + dy * dy;

    if (lengthSquared == 0) {
      return _Projection(
        point: a,
        t: 0,
        distanceToPoint:
            _distance(point, a),
      );
    }

    var t =
        ((px - ax) * dx +
                (py - ay) * dy) /
            lengthSquared;

    t = t.clamp(0.0, 1.0);

    final nearestX =
        ax + t * dx;

    final nearestY =
        ay + t * dy;

    final nearest = LatLng(
      nearestY / scaleY,
      nearestX / scaleX,
    );

    return _Projection(
      point: nearest,
      t: t,
      distanceToPoint:
          _distance(point, nearest),
    );
  }
}

class _Projection {
  final LatLng point;
  final double t;
  final double distanceToPoint;

  const _Projection({
    required this.point,
    required this.t,
    required this.distanceToPoint,
  });
}