import 'package:shared_preferences/shared_preferences.dart';

/// Stores the user's in-app notification preference.
///
/// This is separate from the Android system-level notification
/// permission. Even if the user grants the Android permission,
/// they can still flip this switch to silence Webs
/// without affecting other apps.
class NotificationPreferences {
  NotificationPreferences._();

  static final NotificationPreferences instance =
      NotificationPreferences._();

  static const String _enabledKey =
      'webs_notifications_enabled';

  bool _cachedValue = true;
  bool _loadedOnce = false;

  /// Last known value. Defaults to true until [load] runs.
  bool get cachedEnabled => _cachedValue;

  /// Read the stored value. Call once on app start.
  Future<bool> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(_enabledKey);

    _cachedValue = stored ?? true;
    _loadedOnce = true;

    return _cachedValue;
  }

  /// Persist a new value and update the cache.
  Future<void> setEnabled(bool enabled) async {
    _cachedValue = enabled;
    _loadedOnce = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  /// Whether [load] has already run in this session.
  bool get loadedOnce => _loadedOnce;
}