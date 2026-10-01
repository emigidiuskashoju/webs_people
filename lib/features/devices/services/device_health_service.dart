import 'package:battery_plus/battery_plus.dart';

class DeviceHealthService {
  final Battery _battery = Battery();

  Future<Map<String, dynamic>> getHealth() async {
    final level = await _battery.batteryLevel;
    final state = await _battery.batteryState;

    return {
      'battery_level': level,
      'is_charging':
          state == BatteryState.charging || state == BatteryState.full,
    };
  }
}
