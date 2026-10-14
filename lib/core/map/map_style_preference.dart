import 'package:shared_preferences/shared_preferences.dart';

/// The three map styles the user can pick from.
enum MapStyleKind {
  defaultStyle,   // "streets-v12"
  satellite,      // "satellite-streets-v12"  ← initial default
  terrain,        // "outdoors-v12"
}

extension MapStyleKindLabel on MapStyleKind {
  String get label {
    switch (this) {
      case MapStyleKind.defaultStyle:
        return 'Default';
      case MapStyleKind.satellite:
        return 'Satellite';
      case MapStyleKind.terrain:
        return 'Terrain';
    }
  }

  /// Mapbox style slug used in the tile URL.
  String get mapboxSlug {
    switch (this) {
      case MapStyleKind.defaultStyle:
        return 'streets-v12';
      case MapStyleKind.satellite:
        return 'satellite-streets-v12';
      case MapStyleKind.terrain:
        return 'outdoors-v12';
    }
  }
}

class MapStylePreference {
  static const String _key = 'map_style_kind';

  /// Read the user's saved preference. Defaults to satellite.
  static Future<MapStyleKind> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    return _fromString(raw) ?? MapStyleKind.satellite;
  }

  /// Persist the user's choice.
  static Future<void> save(MapStyleKind kind) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, kind.name);
  }

  static MapStyleKind? _fromString(String? value) {
    if (value == null) return null;
    for (final kind in MapStyleKind.values) {
      if (kind.name == value) return kind;
    }
    return null;
  }
}