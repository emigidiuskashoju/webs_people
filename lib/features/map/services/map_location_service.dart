import 'dart:async';

import 'package:geolocator/geolocator.dart';

class MapLocationService {
  StreamSubscription<Position>?
      _subscription;

  bool get isTracking =>
      _subscription != null;

  Future<bool> _ensurePermission() async {
    final serviceEnabled =
        await Geolocator
            .isLocationServiceEnabled();

    if (!serviceEnabled) {
      return false;
    }

    var permission =
        await Geolocator.checkPermission();

    if (permission ==
        LocationPermission.denied) {
      permission =
          await Geolocator.requestPermission();
    }

    if (permission ==
            LocationPermission.denied ||
        permission ==
            LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<Position>
      getCurrentPosition() async {
    final allowed =
        await _ensurePermission();

    if (!allowed) {
      throw Exception(
        'Location permission or location service is not available.',
      );
    }

    return Geolocator
        .getCurrentPosition(
      locationSettings:
          const LocationSettings(
        accuracy:
            LocationAccuracy.high,
      ),
    );
  }

  Stream<Position>
      startTracking() async* {
    final allowed =
        await _ensurePermission();

    if (!allowed) {
      throw Exception(
        'Location permission or location service is not available.',
      );
    }

    final stream =
        Geolocator.getPositionStream(
      locationSettings:
          const LocationSettings(
        accuracy:
            LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );

    yield* stream;
  }

  void stopTracking() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<void> listen(
    void Function(Position)
        onPosition,
  ) async {
    stopTracking();

    final allowed =
        await _ensurePermission();

    if (!allowed) {
      throw Exception(
        'Location permission or location service is not available.',
      );
    }

    _subscription =
        Geolocator
            .getPositionStream(
      locationSettings:
          const LocationSettings(
        accuracy:
            LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(onPosition);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}