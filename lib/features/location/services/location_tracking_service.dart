import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../map/services/location_request_service.dart';

class LocationTrackingService {
  StreamSubscription<Position>? _subscription;
  int? _deviceId;
  int? _requestId;

  final LocationRequestService _requestService = LocationRequestService();

  bool get isTracking => _subscription != null;

  int? get deviceId => _deviceId;

  int? get requestId => _requestId;

  /// Start tracking.
  ///
  /// Called by the Security (Finding) flow with [deviceId].
  /// Called by the map screen with [requestId] when a location
  /// request is accepted.
  ///
  /// The two are independent: a single instance of this service
  /// can track a deviceId OR a requestId, never both.
  Future<void> start({
    int? deviceId,
    int? requestId,
  }) async {
    // ---------------------------------------------------------
    // CRITICAL: always tear down any existing stream first.
    //
    // This is what makes same-phone two-account testing work.
    // When you switch accounts, the old stream is still bound
    // to the OLD account's token and it will keep uploading
    // to the OLD request row.
    //
    // Stopping here guarantees only ONE stream is ever alive
    // and it always uses the current account's credentials.
    // ---------------------------------------------------------
    await _stopInternal();

    _deviceId = deviceId;
    _requestId = requestId;

    final allowed = await _ensurePermission();
    if (!allowed) {
      throw Exception(
        'Location permission or location service is not available.',
      );
    }

    debugPrint(
      'TRACKING: starting stream deviceId=$deviceId requestId=$requestId',
    );

    _subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
      _onPosition,
      onError: (e) {
        debugPrint('TRACKING: stream error: $e');
      },
    );
  }

  Future<void> _onPosition(Position position) async {
    final requestId = _requestId;

    // If we're only tracking a device (Security flow), the
    // heartbeat service handles the upload. Nothing to do here.
    if (requestId == null) return;

    try {
      await _requestService
          .updateLocation(
            requestId: requestId,
            latitude: position.latitude,
            longitude: position.longitude,
            accuracy: position.accuracy,
          )
          .timeout(const Duration(seconds: 10));

      debugPrint(
        'TRACKING: uploaded lat=${position.latitude} '
        'lng=${position.longitude} for request=$requestId',
      );
    } catch (e) {
      debugPrint('TRACKING: upload failed: $e');
    }
  }

  Future<void> stop() async {
    await _stopInternal();
  }

  Future<void> _stopInternal() async {
    await _subscription?.cancel();
    _subscription = null;
    _deviceId = null;
    _requestId = null;
  }

  Future<bool> _ensurePermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return false;

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
}