import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

import 'map_style_preference.dart';

/// Central place for the Mapbox access token.
///
/// This is a PUBLIC token (starts with `pk.`), which is safe to ship
/// inside an app. Restrict it in the Mapbox dashboard by URL and scopes
/// to prevent abuse.
const String kMapboxAccessToken = 'pk.eyJ1IjoiZW1pZ2lkaXVzIiwiYSI6ImNtc3R6NmdnaDBkanAyeXNpZGV2bnVobm0ifQ.agILU8E5-HQb78tWl-zKHA';

/// A ready-to-use [TileLayer] that renders the chosen Mapbox style.
class MapboxTileLayer {
  /// Returns a [TileLayer] for the given [MapStyleKind].
  ///
  /// Defaults to satellite when no style is passed.
  static Widget forStyle([
    MapStyleKind kind = MapStyleKind.satellite,
  ]) {
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