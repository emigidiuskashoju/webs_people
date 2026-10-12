import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/map/mapbox_tile_layer.dart';
import '../map/widgets/photo_marker.dart';

class RecoveryMap extends StatefulWidget {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final String? deviceName;

  const RecoveryMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.deviceName,
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

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
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

  @override
  Widget build(BuildContext context) {
    final center = LatLng(widget.latitude, widget.longitude);

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

            MarkerLayer(
              markers: [
                Marker(
                  point: center,
                  width: 70,
                  height: 90,
                  alignment: Alignment.topCenter,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      // Animated heartbeat rings behind the marker
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

                      // Photo marker with red ring
                      Positioned(
                        top: 0,
                        child: PhotoMarker(
                          photoUrl: null,
                          fallbackInitial:
                              widget.deviceName ?? 'D',
                          ringColor: _heartbeatRed,
                          fillColor: _heartbeatFill,
                          size: 50,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),

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