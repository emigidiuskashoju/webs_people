import 'dart:async';

import 'device_command_processor.dart';

class DeviceCommandPollingService {
  final DeviceCommandProcessor _processor;

  Timer? _timer;

  bool _running = false;

  DeviceCommandPollingService({DeviceCommandProcessor? processor})
    : _processor = processor ?? DeviceCommandProcessor();

  Future<void> start({required int deviceId}) async {
    await stop();

    _running = true;

    await _process(deviceId);

    _timer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!_running) {
        return;
      }

      await _process(deviceId);
    });
  }

  Future<void> _process(int deviceId) async {
    try {
      await _processor.process(deviceId: deviceId);
    } catch (e) {
      print('WEBS COMMAND ERROR: $e');
    }
  }

  Future<void> stop() async {
    _running = false;

    _timer?.cancel();

    _timer = null;
  }

  Future<void> dispose() async {
    await stop();
  }
}
