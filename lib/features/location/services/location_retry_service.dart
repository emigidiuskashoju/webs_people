import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../devices/services/device_service.dart';
import 'location_queue_service.dart';

class LocationRetryService {
  final LocationQueueService _queueService;
  final DeviceService _deviceService;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  Timer? _retryTimer;

  bool _isProcessing = false;

  LocationRetryService({
    LocationQueueService? queueService,
    DeviceService? deviceService,
  }) : _queueService = queueService ?? LocationQueueService(),
       _deviceService = deviceService ?? DeviceService();

  Future<void> start() async {
    await stop();

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) async {
      final hasConnection = results.any(
        (result) => result != ConnectivityResult.none,
      );

      if (hasConnection) {
        await processQueue();
      }
    });

    _retryTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      await processQueue();
    });

    await processQueue();
  }

  Future<void> processQueue() async {
    if (_isProcessing) {
      return;
    }

    _isProcessing = true;

    try {
      final queue = await _queueService.getQueue();

      if (queue.isEmpty) {
        return;
      }

      final remaining = <LocationQueueItem>[];

      for (final item in queue) {
        try {
          await _deviceService.sendLocation(
            deviceId: item.deviceId,
            location: item.location,
          );

          print(
            'WEBS QUEUE: uploaded '
            '${item.location.latitude}, '
            '${item.location.longitude}',
          );
        } catch (e) {
          print('WEBS QUEUE: upload failed: $e');

          remaining.add(item);
        }
      }

      await _queueService.replaceQueue(remaining);

      print(
        'WEBS QUEUE: '
        '${remaining.length} locations remaining',
      );
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> stop() async {
    await _connectivitySubscription?.cancel();

    _connectivitySubscription = null;

    _retryTimer?.cancel();

    _retryTimer = null;
  }

  Future<int> pendingCount() async {
    return _queueService.count();
  }

  Future<void> dispose() async {
    await stop();
  }
}
