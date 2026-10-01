import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

class DeviceInfoService {
  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  Future<Map<String, dynamic>> getDeviceInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();

    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfoPlugin.androidInfo;

      return {
        'platform': 'android',
        'model': androidInfo.model,
        'manufacturer': androidInfo.manufacturer,
        'os_version': androidInfo.version.release,
        'app_version': packageInfo.version,
      };
    }

    if (Platform.isIOS) {
      final iosInfo = await _deviceInfoPlugin.iosInfo;

      return {
        'platform': 'ios',
        'model': iosInfo.utsname.machine,
        'manufacturer': 'Apple',
        'os_version': iosInfo.systemVersion,
        'app_version': packageInfo.version,
      };
    }

    return {
      'platform': Platform.operatingSystem,
      'model': 'Unknown',
      'manufacturer': 'Unknown',
      'os_version': Platform.operatingSystemVersion,
      'app_version': packageInfo.version,
    };
  }

  Future<String> getDefaultDeviceName() async {
    final info = await getDeviceInfo();

    final manufacturer = info['manufacturer'];
    final model = info['model'];

    if (manufacturer is String &&
        model is String &&
        manufacturer.isNotEmpty &&
        model.isNotEmpty &&
        manufacturer != 'Unknown' &&
        model != 'Unknown') {
      return '$manufacturer $model';
    }

    if (model is String && model.isNotEmpty) {
      return model;
    }

    return 'My Webs Device';
  }
}
