import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../core/map/mapbox_tile_layer.dart';
import '../map/widgets/photo_marker.dart';
import '../map/widgets/route_flow_dots.dart';

class RecoveryMap extends StatefulWidget {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final String? deviceName;

  /// The user's own position (the "you are here" point).
  /// When both are non-null, a red route is drawn from here to
  /// the device marker, with red direction dots animating along
  /// it.
  final double? userLatitude;
  final double? userLongitude;

  const RecoveryMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.deviceName,
    this.userLatitude,
    this.userLongitude,
  });

  @override
  State<RecoveryMap> createState() => _RecoveryMapState();
}

class _RecoveryMapState extends State<RecoveryMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  final MapController _mapController = MapController();

  static const Color _heartbeatRed = Color(0xFFE53935);
  static const Color _heartbeatRedDeep = Color(0xFFB71C1C);
  static const Color _heartbeatFill = Color(0xFFFFEBEE);

  /// The user's own position, distinct from the "lost device"
  /// marker. A blue pin with a small dot.
  static const Color _userBlue = Color(0xFF1976D2);
  static const Color _userBlueFill = Color(0xFFE3F2FD);

  // Route state.
  List<LatLng> _routeGeometry = const <LatLng>[];
  bool _routeLoading = false;
  LatLng? _routeFrom; // the user's position at fetch time
  String? _routeError;

  // How far the user must move (meters) before we auto-refetch.
  static const double _rerouteThresholdMeters = 100.0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _maybeFetchRoute(force: true);
  }

  @override
  void didUpdateWidget(covariant RecoveryMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    final userMoved = oldWidget.userLatitude != widget.userLatitude ||
        oldWidget.userLongitude != widget.userLongitude;
    final deviceMoved = oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude;

    if (userMoved || deviceMoved) {
      _maybeFetchRoute();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  double _heartbeatCurve(double t) {
    if (t < 0.15) {
      return Curves.easeOut.transform(t / 0.15);
    } else if (t < 0.30) {
      return 1.0 - Curves.easeIn.transform((t - 0.15) / 0.15);
    } else if (t < 0.45) {
      return Curves.easeOut.transform((t - 0.30) / 0.15);
    } else {
      return (1.0 - Curves.easeIn.transform((t - 0.45) / 0.55))
          .clamp(0.0, 1.0);
    }
  }

  // ============================================================
  // ROUTE FETCH
  // ============================================================

  Future<void> _maybeFetchRoute({bool force = false}) async {
    final userLat = widget.userLatitude;
    final userLng = widget.userLongitude;
    if (userLat == null || userLng == null) return;

    final from = LatLng(userLat, userLng);
    final to = LatLng(widget.latitude, widget.longitude);

    // Throttle: only refetch if we don't have a route, or the user
    // has moved at least _rerouteThresholdMeters since last fetch,
    // or the caller passed force: true.
    if (!force && _routeFrom != null) {
      final moved = const Distance().as(
        LengthUnit.Meter,
        _routeFrom!,
        from,
      );
      if (moved < _rerouteThresholdMeters) return;
    }

    if (!mounted) return;
    setState(() {
      _routeLoading = true;
      _routeError = null;
    });

    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${from.longitude},${from.latitude};'
        '${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson',
      );
      final response =
          await http.get(url).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        if (mounted) {
          setState(() {
            _routeLoading = false;
            _routeError = 'Route service returned '
                '${response.statusCode}.';
          });
        }
        return;
      }

      final data = jsonDecode(response.body);
      final routes = data['routes'];
      if (routes is! List || routes.isEmpty) {
        if (mounted) {
          setState(() {
            _routeLoading = false;
            _routeError = 'No route found.';
          });
        }
        return;
      }

      final geometry = routes.first['geometry'];
      final coordinates = geometry['coordinates'];
      if (coordinates is! List) {
        if (mounted) {
          setState(() {
            _routeLoading = false;
            _routeError = 'Invalid route response.';
          });
        }
        return;
      }

      final points = coordinates
          .whereType<List>()
          .where((item) => item.length >= 2)
          .map((item) => LatLng(
                (item[1] as num).toDouble(),
                (item[0] as num).toDouble(),
              ))
          .toList();

      if (points.length < 2) {
        if (mounted) {
          setState(() {
            _routeLoading = false;
            _routeError = 'Route has no geometry.';
          });
        }
        return;
      }

      if (!mounted) return;
      setState(() {
        _routeGeometry = points;
        _routeFrom = from;
        _routeLoading = false;
        _routeError = null;
      });

      // Fit camera to both endpoints once the first route lands.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final bounds = LatLngBounds.fromPoints([from, to]);
        try {
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.fromLTRB(50, 90, 50, 50),
            ),
          );
        } catch (_) {}
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _routeLoading = false;
        _routeError = 'Route failed: $e';
      });
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final center = LatLng(widget.latitude, widget.longitude);

    final hasUser =
        widget.userLatitude != null && widget.userLongitude != null;
    final userPoint = hasUser
        ? LatLng(widget.userLatitude!, widget.userLongitude!)
        : null;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 17,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            MapboxTileLayer.streets(),

            if (widget.accuracy != null && widget.accuracy! > 0)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: center,
                    radius: widget.accuracy!.clamp(5, 200),
                    useRadiusInMeter: true,
                    color: _heartbeatRed.withValues(alpha: 0.12),
                    borderColor: _heartbeatRed.withValues(alpha: 0.35),
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),

            // Red route between user and device.
            if (_routeGeometry.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routeGeometry,
                    strokeWidth: 5,
                    color: _heartbeatRed,
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                ],
              ),

            // Red direction dots on the route.
            if (_routeGeometry.length >= 2)
              RouteFlowDotsLayer(
                route: _routeGeometry,
                dotCount: 2,
                pixelsPerSecond: 70.0,
                color: _heartbeatRed,
              ),

            MarkerLayer(
              markers: [
                // The lost device — red heartbeat pin (unchanged).
                Marker(
                  point: center,
                  width: 70,
                  height: 90,
                  alignment: Alignment.topCenter,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Positioned(
                        top: 0,
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, _) {
                            final beat = _heartbeatCurve(
                              _pulseController.value,
                            );
                            return _HeartbeatRings(beat: beat);
                          },
                        ),
                      ),
                      Positioned(
                        top: 0,
                        child: PhotoMarker(
                          photoUrl: null,
                          fallbackInitial: widget.deviceName ?? 'D',
                          ringColor: _heartbeatRed,
                          fillColor: _heartbeatFill,
                          size: 50,
                        ),
                      ),
                    ],
                  ),
                ),

                // The user's own position — blue pin.
                if (userPoint != null)
                  Marker(
                    point: userPoint,
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: _userBlue,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _userBlue.withValues(alpha: 0.35),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.person_pin_circle,
                          color: _userBlue,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),

        // LIVE badge (unchanged).
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: _heartbeatRedDeep,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _heartbeatRed.withValues(alpha: 0.45),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Route loading indicator.
        if (_routeLoading)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Building route…',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Route error (non-fatal — the map still shows both pins).
        if (_routeError != null && !_routeLoading)
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.orange.shade800.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _routeError!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _maybeFetchRoute(force: true),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        'Retry',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _HeartbeatRings extends StatelessWidget {
  final double beat;

  const _HeartbeatRings({required this.beat});

  static const Color _red = Color(0xFFE53935);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _ripple(
            size: 100 + (beat * 20),
            opacity: 0.18 * (1.0 - beat * 0.5),
          ),
          _ripple(
            size: 70 + (beat * 30),
            opacity: 0.35 * (1.0 - beat * 0.6),
          ),
        ],
      ),
    );
  }

  Widget _ripple({
    required double size,
    required double opacity,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _red.withValues(alpha: opacity),
        border: Border.all(
          color: _red.withValues(alpha: opacity + 0.15),
          width: 1.5,
        ),
      ),
    );
  }
}