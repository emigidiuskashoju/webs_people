import 'dart:async';

import 'package:flutter/material.dart';

class LocationTickerData {
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final double? speedMetersPerSecond;
  final String? address;

  const LocationTickerData({
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.speedMetersPerSecond,
    this.address,
  });

  bool get hasData => latitude != null && longitude != null;
}

class LocationTicker extends StatefulWidget {
  final LocationTickerData data;
  final double pixelsPerSecond;

  const LocationTicker({
    super.key,
    required this.data,
    this.pixelsPerSecond = 40.0, // slow, comfortable reading
  });

  @override
  State<LocationTicker> createState() => _LocationTickerState();
}

class _LocationTickerState extends State<LocationTicker> {
  static const Color _barBackground = Color(0xFF0A0A0A);
  static const Color _goldLabel = Color(0xFFD4AF37);
  static const Color _greenValue = Color(0xFF4CAF50);

  final ScrollController _scrollController = ScrollController();
  Timer? _timer;
  double _offset = 0.0;
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _start() {
    if (_hasStarted) return;
    _hasStarted = true;

    // 60 fps tick — advance by pixelsPerSecond/60 each tick.
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted) return;
      if (!_scrollController.hasClients) return;

      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) return;

      // Advance the scroll offset smoothly.
      _offset += widget.pixelsPerSecond / 60.0;

      // Wrap around to give the illusion of an endless loop.
      if (_offset >= maxScroll) {
        _offset = 0;
      }

      _scrollController.jumpTo(_offset);
    });
  }

  String _formatCoord(double? value) {
    if (value == null) return '--';
    return value.toStringAsFixed(6);
  }

  String _formatAccuracy(double? value) {
    if (value == null) return '--';
    return '±${value.toStringAsFixed(1)} meters';
  }

  String _formatSpeed(double? value) {
    if (value == null) return '--';
    final kmh = value * 3.6;
    return '${kmh.toStringAsFixed(1)} km/h';
  }

  List<Widget> _buildSegments() {
    final d = widget.data;
    final segments = <Widget>[];

    void add(String label, String value) {
      segments.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, height: 1.2),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                    color: _goldLabel,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    color: _greenValue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      segments.add(
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            '•',
            style: TextStyle(color: _goldLabel, fontSize: 13),
          ),
        ),
      );
    }

    add('Location', (d.address ?? 'Locating…'));
    add('Latitude', _formatCoord(d.latitude));
    add('Longitude', _formatCoord(d.longitude));
    add('Accuracy', _formatAccuracy(d.accuracyMeters));
    add('Speed', _formatSpeed(d.speedMetersPerSecond));

    return segments;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.data.hasData) {
      return Container(
        height: 30,
        color: _barBackground,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Current Location: ',
                style: TextStyle(
                  color: _goldLabel,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: 'Waiting for GPS fix…',
                style: TextStyle(
                  color: _greenValue,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Duplicate the content so the wrap-around is invisible —
    // the ticker appears to scroll forever.
    final segmentChildren = <Widget>[
      const SizedBox(width: 12),
      ..._buildSegments(),
      ..._buildSegments(),
      ..._buildSegments(),
      const SizedBox(width: 12),
    ];

    return Container(
      height: 30,
      color: _barBackground,
      child: ClipRect(
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Row(children: segmentChildren),
        ),
      ),
    );
  }
}