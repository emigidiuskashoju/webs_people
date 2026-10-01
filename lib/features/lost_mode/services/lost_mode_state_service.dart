import 'package:shared_preferences/shared_preferences.dart';

class LostModeStateService {
  static const String _prefix = 'webs_lost_mode_';

  Future<void> setEnabled(int deviceId, bool enabled) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setBool('$_prefix$deviceId', enabled);
  }

  Future<bool> isEnabled(int deviceId) async {
    final preferences = await SharedPreferences.getInstance();

    return preferences.getBool('$_prefix$deviceId') ?? false;
  }

  Future<void> clear(int deviceId) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.remove('$_prefix$deviceId');
  }
}
