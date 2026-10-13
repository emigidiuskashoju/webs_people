import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class MapLocationService {
  StreamSubscription<Position>? _subscription;

  /// Maximum GPS accuracy (in meters) we consider usable.
  /// Anything worse is likely a cell-tower or Wi-Fi fix and
  /// will put the user hundreds or thousands of meters off.
  static const double maxAcceptableAccuracyMeters = 100.0;

  bool get isTracking => _subscription != null;

  Future<bool> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      return false;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<Position> getCurrentPosition() async {
    final allowed = await _ensurePermission();

    if (!allowed) {
      throw Exception(
        'Location permission or location service is not available.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
      ),
    );
  }

  Stream<Position> startTracking() async* {
    final allowed = await _ensurePermission();

    if (!allowed) {
      throw Exception(
        'Location permission or location service is not available.',
      );
    }

    final stream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).where(_isAcceptableAccuracy);

    yield* stream;
  }

  void stopTracking() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<void> listen(
    void Function(Position) onPosition,
  ) async {
    stopTracking();

    final allowed = await _ensurePermission();

    if (!allowed) {
      throw Exception(
        'Location permission or location service is not available.',
      );
    }

    _subscription = Geolocator
        .getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    )
        .where(_isAcceptableAccuracy)
        .listen(onPosition);
  }

  bool _isAcceptableAccuracy(Position position) {
    if (position.accuracy > maxAcceptableAccuracyMeters) {
      debugPrint(
        'LOCATION: rejecting fix — accuracy='
        '${position.accuracy.toStringAsFixed(1)}m '
        '(limit ${maxAcceptableAccuracyMeters.toStringAsFixed(0)}m)',
      );
      return false;
    }
    return true;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}