import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

import 'map_style_preference.dart';

/// Central place for the Mapbox access token.
///
/// This is a PUBLIC token (starts with `pk.`), which is safe to ship
/// inside an app. Restrict it in the Mapbox dashboard by URL and scopes
/// to prevent abuse.
const String kMapboxAccessToken =
    'pk.eyJ1IjoiZW1pZ2lkaXVzIiwiYSI6ImNtc3R6NmdnaDBkanAyeXNpZGV2bnVobm0ifQ.agILU8E5-HQb78tWl-zKHA';

/// Builds the right [TileLayer] for each [MapStyleKind].
class MapboxTileLayer {
  /// Returns a [TileLayer] for the given [MapStyleKind].
  ///
  /// Mapbox styles use 512px tiles with a -1 zoom offset. The
  /// high-detail satellite style is served by Esri World Imagery,
  /// which uses standard 256px {z}/{y}/{x} tiles instead.
  static Widget forStyle([
    MapStyleKind kind = MapStyleKind.satellite,
  ]) {
    if (!kind.isMapbox) {
      // Esri World Imagery — note the {z}/{y}/{x} order (y before x).
      return TileLayer(
        urlTemplate:
            'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
        userAgentPackageName: 'com.webspeople.app',
        maxNativeZoom: 19,
      );
    }

    return TileLayer(
      urlTemplate:
          'https://api.mapbox.com/styles/v1/mapbox/${kind.mapboxSlug}/tiles/{z}/{x}/{y}?access_token=$kMapboxAccessToken',
      tileDimension: 512,
      zoomOffset: -1,
      userAgentPackageName: 'com.webspeople.app',
    );
  }

  /// Legacy alias. Kept so existing calls keep compiling.
  static Widget streets() => forStyle(MapStyleKind.defaultStyle);
}
