import '../../devices/services/device_service.dart';
import '../models/recovery_device.dart';

class RecoveryService {
  final DeviceService _deviceService;

  RecoveryService({DeviceService? deviceService})
    : _deviceService = deviceService ?? DeviceService();

  Future<List<RecoveryDevice>> getRecoveryDevices() async {
    final devices = await _deviceService.getRecoveryDevices();

    return devices.map((device) => RecoveryDevice.fromJson(device)).toList();
  }

  Future<List<Map<String, dynamic>>> getLocationHistory(int deviceId) async {
    return _deviceService.getDeviceLocations(deviceId);
  }
}
