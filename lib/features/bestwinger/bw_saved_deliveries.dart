import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A delivery the user opened before, so it is one tap away on the Track tab.
class BwSavedDelivery {
  final String role; // 'buyer' or 'seller'
  final String key; // the order code (buyer) or the secure link (seller)
  final String code;
  final String title;
  final DateTime savedAt;

  const BwSavedDelivery({
    required this.role,
    required this.key,
    required this.code,
    required this.title,
    required this.savedAt,
  });

  bool get isSeller => role == 'seller';

  Map<String, dynamic> toJson() => {
        'role': role,
        'key': key,
        'code': code,
        'title': title,
        'savedAt': savedAt.toIso8601String(),
      };

  static BwSavedDelivery? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final key = raw['key'];
    if (key is! String || key.isEmpty) return null;
    return BwSavedDelivery(
      role: raw['role'] == 'seller' ? 'seller' : 'buyer',
      key: key,
      code: raw['code'] as String? ?? '',
      title: raw['title'] as String? ?? '',
      savedAt: DateTime.tryParse(raw['savedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class BwSavedDeliveries {
  static const String _prefsKey = 'bestwinger_saved_deliveries';
  static const int _max = 20;

  static Future<List<BwSavedDelivery>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return [];
    try {
      final list = (jsonDecode(raw) as List).map(BwSavedDelivery.fromJson).whereType<BwSavedDelivery>().toList();
      list.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Adds or refreshes a delivery (newest first, at most 20).
  static Future<void> remember(BwSavedDelivery d) async {
    final list = (await load()).where((x) => x.key != d.key).toList()..insert(0, d);
    await _write(list.take(_max).toList());
  }

  static Future<void> forget(String key) async {
    await _write((await load()).where((x) => x.key != key).toList());
  }

  static Future<void> _write(List<BwSavedDelivery> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(list.map((d) => d.toJson()).toList()));
  }
}
