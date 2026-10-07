import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/widgets.dart';

/// Central place for the Mapbox access token.
///
/// This is a PUBLIC token (starts with `pk.`), which is safe to ship
/// inside an app. Restrict it in the Mapbox dashboard by URL and scopes
/// to prevent abuse.
const String kMapboxAccessToken =
    'pk.eyJ1IjoiZW1pZ2lkaXVzIiwiYSI6ImNtc3R6NmdnaDBkanAyeXNpZGV2bnVobm0ifQ.agILU8E5-HQb78tWl-zKHA';

/// A ready-to-use [TileLayer] that renders Mapbox "streets" style.
///
/// Drop this in place of the old OpenStreetMap [TileLayer] in any
/// [FlutterMap].
class MapboxTileLayer {
  static Widget streets() {
    return TileLayer(
      urlTemplate:
          'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}?access_token=$kMapboxAccessToken',
      tileDimension: 512,
      zoomOffset: -1,
      userAgentPackageName: 'com.webspeople.app',
    );
  }
}
