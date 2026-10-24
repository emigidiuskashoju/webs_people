import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Draws a small number of golden dots that travel along [route]
/// in the direction of travel, repeatedly, until the widget is
/// removed.
///
/// The dots move at a fixed screen-space speed (pixels per tick),
/// so their visual speed is identical at every zoom level — which
/// is what makes them readable as a "direction of travel" cue.
///
/// Intended to be added as a child of a `FlutterMap` right after
/// the `PolylineLayer` for the route you want to animate.
class RouteFlowDotsLayer extends StatefulWidget {
  /// The polyline to travel along. Must have at least 2 points.
  final List<LatLng> route;

  /// How many dots should be on screen at once.
  final int dotCount;

  /// Radius of each golden dot in logical pixels.
  final double dotRadius;

  /// Screen-space speed of the dots in logical pixels per second.
  final double pixelsPerSecond;

  /// The dot color. Defaults to a golden yellow.
  final Color color;

  /// How far apart consecutive dots are, as a fraction of the
  /// total route length. 0.5 with `dotCount: 2` puts the two dots
  /// half a loop apart, i.e. evenly spaced in time.
  final double spacingFraction;

  const RouteFlowDotsLayer({
    super.key,
    required this.route,
    this.dotCount = 2,
    this.dotRadius = 4.0,
    this.pixelsPerSecond = 60.0,
    this.color = const Color(0xFFFFC107),
    this.spacingFraction = 0.5,
  });

  @override
  State<RouteFlowDotsLayer> createState() =>
      _RouteFlowDotsLayerState();
}

class _RouteFlowDotsLayerState extends State<RouteFlowDotsLayer> {
  /// Drives animation. Restarted only when the route changes.
  Timer? _ticker;

  /// Elapsed time since the last route change.
  Duration _elapsed = Duration.zero;

  /// Cumulative distances along the route in meters, and the
  /// total. Recomputed whenever the route changes.
  List<double> _cumulativeMeters = const <double>[];
  double _totalMeters = 0;

  /// Cached pixels-per-meter at the current zoom. Recomputed each
  /// build from the current camera, but cached so we don't call
  /// latLngToScreenOffset twice per tick unnecessarily.


  @override
  void initState() {
    super.initState();
    _rebuildRouteMetrics();
    _startTicker();
  }

  @override
  void didUpdateWidget(covariant RouteFlowDotsLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final routeChanged = !identical(oldWidget.route, widget.route) ||
        oldWidget.route.length != widget.route.length;
    if (routeChanged) {
      _rebuildRouteMetrics();
      _elapsed = Duration.zero;
      _startTicker();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(
      const Duration(milliseconds: 40),
      (_) {
        if (!mounted) return;
        setState(() => _elapsed += const Duration(milliseconds: 40));
      },
    );
  }

  void _rebuildRouteMetrics() {
    final route = widget.route;
    if (route.length < 2) {
      _cumulativeMeters = const <double>[];
      _totalMeters = 0;
      return;
    }

    const calc = Distance();
    final cum = List<double>.filled(route.length, 0);
    double total = 0;
    for (int i = 1; i < route.length; i++) {
      total += calc.as(LengthUnit.Meter, route[i - 1], route[i]);
      cum[i] = total;
    }
    _cumulativeMeters = cum;
    _totalMeters = total;
  }

  /// Interpolates a LatLng at [meters] along the route.
  /// Returns null if the route is empty.
  LatLng? _pointAtMeters(double meters) {
    final route = widget.route;
    if (route.length < 2 || _totalMeters <= 0) return null;

    final clamped = meters.clamp(0.0, _totalMeters);

    // Binary search for the segment that contains `clamped`.
    int lo = 0;
    int hi = _cumulativeMeters.length - 1;
    while (lo + 1 < hi) {
      final mid = (lo + hi) >> 1;
      if (_cumulativeMeters[mid] <= clamped) {
        lo = mid;
      } else {
        hi = mid;
      }
    }

    final segStartM = _cumulativeMeters[lo];
    final segEndM = _cumulativeMeters[hi];
    final segLen = segEndM - segStartM;
    final t = segLen == 0 ? 0.0 : (clamped - segStartM) / segLen;

    final a = route[lo];
    final b = route[hi];
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  /// Returns how many logical pixels 1 meter covers at the current
  /// zoom level. Uses `MapCamera.latLngToScreenOffset` on two
  /// LatLngs that are 1 m apart at the camera's center — this API
  /// is stable across flutter_map 7.x and 8.x.
  double _computePixelsPerMeter(MapCamera camera) {
    try {
      final center = camera.center;
      // 1 meter east of center. Latitude delta ~= 0 at this scale.
      final oneMeterEast = const Distance().offset(center, 1.0, 90);
      final a = camera.latLngToScreenOffset(center);
      final b = camera.latLngToScreenOffset(oneMeterEast);
      final dx = b.dx - a.dx;
      final dy = b.dy - a.dy;
      final dist = (dx * dx + dy * dy);
      if (dist.isFinite && dist > 0) return _sqrt(dist);
      return 0;
    } catch (_) {
      return 0;
    }
  }

  double _sqrt(double x) {
    // Simple Newton–Raphson sqrt (avoids importing dart:math).
    if (x <= 0) return 0;
    double guess = x;
    for (int i = 0; i < 20; i++) {
      guess = 0.5 * (guess + x / guess);
    }
    return guess;
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    if (route.length < 2 || _totalMeters <= 0) {
      return const SizedBox.shrink();
    }

    // Get the current camera. If this throws (e.g. because the
    // layer is being built outside a FlutterMap), bail out.
    final MapCamera camera;
    try {
      camera = MapCamera.of(context);
    } catch (_) {
      return const SizedBox.shrink();
    }

    final pixelsPerMeter = _computePixelsPerMeter(camera);

    // Fall back to a sane meters/second if we couldn't measure.
    final metersPerSecond = pixelsPerMeter > 0
        ? widget.pixelsPerSecond / pixelsPerMeter
        : 5.0;

    final leadMeters =
        (_elapsed.inMicroseconds / 1e6) * metersPerSecond;
    final loopMeters = _totalMeters;
    if (loopMeters <= 0) return const SizedBox.shrink();

    final markers = <Marker>[];
    for (int i = 0; i < widget.dotCount; i++) {
      final offset =
          leadMeters - (i * widget.spacingFraction * loopMeters);
      final meters = offset % loopMeters;
      final point = _pointAtMeters(meters);
      if (point == null) continue;

      markers.add(
        Marker(
          point: point,
          width: widget.dotRadius * 2 + 4,
          height: widget.dotRadius * 2 + 4,
          alignment: Alignment.center,
          child: IgnorePointer(
            child: Container(
              width: widget.dotRadius * 2,
              height: widget.dotRadius * 2,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.55),
                    blurRadius: widget.dotRadius * 2,
                    spreadRadius: widget.dotRadius * 0.4,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MarkerLayer(markers: markers);
  }
}