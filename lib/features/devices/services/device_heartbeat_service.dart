import 'dart:async';

import '../services/device_service.dart';

class DeviceHeartbeatService {
  final DeviceService _deviceService;

  Timer? _timer;

  int? _deviceId;

  bool _isRunning = false;

  DeviceHeartbeatService({
    DeviceService? deviceService,
  }) : _deviceService =
            deviceService ?? DeviceService();

  // ============================================================
  // STATE
  // ============================================================

  bool get isRunning => _isRunning;

  int? get deviceId => _deviceId;

  // ============================================================
  // START
  // ============================================================

  Future<void> start({
    required int deviceId,
  }) async {
    _deviceId = deviceId;

    _timer?.cancel();

    _isRunning = true;

    /*
     * Send the first heartbeat immediately.
     */
    try {
      await _deviceService.heartbeat(
        deviceId,
      );
    } catch (_) {
      /*
       * Do not stop the heartbeat loop if one
       * request temporarily fails.
       */
    }

    /*
     * Send another heartbeat every 30 seconds.
     */
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) async {
        await _sendHeartbeat();
      },
    );
  }

  // ============================================================
  // SEND HEARTBEAT
  // ============================================================

  Future<void> _sendHeartbeat() async {
    final id = _deviceId;

    if (!_isRunning || id == null) {
      return;
    }

    try {
      await _deviceService.heartbeat(
        id,
      );
    } catch (_) {
      /*
       * A temporary network failure should not
       * destroy the heartbeat service.
       *
       * The next timer tick will retry.
       */
    }
  }

  // ============================================================
  // STOP
  // ============================================================

  void stop() {
    _isRunning = false;

    _timer?.cancel();
    _timer = null;

    _deviceId = null;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  void dispose() {
    stop();
  }
}