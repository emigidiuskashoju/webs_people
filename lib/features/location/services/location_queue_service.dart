import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/device_location.dart';

class LocationQueueItem {
  final int deviceId;
  final DeviceLocation location;

  const LocationQueueItem({required this.deviceId, required this.location});

  Map<String, dynamic> toJson() {
    return {'device_id': deviceId, 'location': location.toJson()};
  }

  factory LocationQueueItem.fromJson(Map<String, dynamic> json) {
    return LocationQueueItem(
      deviceId: int.parse(json['device_id'].toString()),
      location: DeviceLocation.fromJson(
        Map<String, dynamic>.from(json['location']),
      ),
    );
  }
}

class LocationQueueService {
  static const String _queueKey = 'webs_pending_locations';

  static const int _maxQueueSize = 500;

  Future<List<LocationQueueItem>> getQueue() async {
    final preferences = await SharedPreferences.getInstance();

    final raw = preferences.getStringList(_queueKey) ?? [];

    final result = <LocationQueueItem>[];

    for (final item in raw) {
      try {
        final decoded = jsonDecode(item);

        if (decoded is Map<String, dynamic>) {
          result.add(LocationQueueItem.fromJson(decoded));
        }
      } catch (_) {
        // Ignore corrupted items.
      }
    }

    return result;
  }

  Future<void> add({
    required int deviceId,
    required DeviceLocation location,
  }) async {
    final preferences = await SharedPreferences.getInstance();

    final queue = preferences.getStringList(_queueKey) ?? [];

    final item = LocationQueueItem(deviceId: deviceId, location: location);

    queue.add(jsonEncode(item.toJson()));

    while (queue.length > _maxQueueSize) {
      queue.removeAt(0);
    }

    await preferences.setStringList(_queueKey, queue);
  }

  Future<void> replaceQueue(List<LocationQueueItem> items) async {
    final preferences = await SharedPreferences.getInstance();

    final values = items.map((item) => jsonEncode(item.toJson())).toList();

    await preferences.setStringList(_queueKey, values);
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.remove(_queueKey);
  }

  Future<int> count() async {
    final preferences = await SharedPreferences.getInstance();

    final queue = preferences.getStringList(_queueKey) ?? [];

    return queue.length;
  }
}
