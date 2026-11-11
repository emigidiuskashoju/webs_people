import 'package:shared_preferences/shared_preferences.dart';

/// The map styles the user can pick from.
///
/// IMPORTANT: the enum identifiers (defaultStyle, satellite, ...) are
/// saved to disk, so they must not be renamed. Labels and the order
/// shown in the picker can change freely.
enum MapStyleKind {
  defaultStyle, // Mapbox streets-v12
  satellite, // Mapbox satellite-streets-v12 (imagery + labels)
  terrain, // Mapbox outdoors-v12
  satelliteHd, // Esri World Imagery (high-detail satellite)
}

extension MapStyleKindInfo on MapStyleKind {
  /// Short name shown under the thumbnail.
  String get label {
    switch (this) {
      case MapStyleKind.defaultStyle:
        return 'Streets';
      case MapStyleKind.satellite:
        return 'Hybrid';
      case MapStyleKind.terrain:
        return 'Terrain';
      case MapStyleKind.satelliteHd:
        return 'Satellite';
    }
  }

  /// One line describing the style, shown under the label.
  String get description {
    switch (this) {
      case MapStyleKind.defaultStyle:
        return 'Standard street map';
      case MapStyleKind.satellite:
        return 'Satellite with street names';
      case MapStyleKind.terrain:
        return 'Hills, trails and nature';
      case MapStyleKind.satelliteHd:
        return 'High-detail satellite imagery';
    }
  }

  /// True for styles served by Mapbox (vs another tile provider).
  bool get isMapbox => this != MapStyleKind.satelliteHd;

  /// Mapbox style slug used in the tile URL (Mapbox styles only).
  String get mapboxSlug {
    switch (this) {
      case MapStyleKind.defaultStyle:
        return 'streets-v12';
      case MapStyleKind.satellite:
        return 'satellite-streets-v12';
      case MapStyleKind.terrain:
        return 'outdoors-v12';
      case MapStyleKind.satelliteHd:
        return 'satellite-v9'; // only used for the preview thumbnail
    }
  }

  /// Attribution text that must be shown on the map for this style.
  String get attribution {
    switch (this) {
      case MapStyleKind.satelliteHd:
        return '© Esri, Maxar, Earthstar Geographics';
      default:
        return '© Mapbox © OpenStreetMap';
    }
  }
}

class MapStylePreference {
  static const String _key = 'map_style_kind';

  /// Read the user's saved preference. Defaults to high-detail satellite.
  static Future<MapStyleKind> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    return _fromString(raw) ?? MapStyleKind.satelliteHd;
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
