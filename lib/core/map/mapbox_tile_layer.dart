import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// Central place for the Mapbox access token.
const String kMapboxAccessToken =
    'PASTE_YOUR_MAPBOX_TOKEN_HERE';

/// A ready-to-use [TileLayer] that renders Mapbox
/// "satellite-streets" style — satellite imagery with street
/// labels and road names overlaid.
class MapboxTileLayer {
  static Widget streets() {
    return TileLayer(
      urlTemplate:
          'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/tiles/{z}/{x}/{y}?access_token=$kMapboxAccessToken',
      tileDimension: 512,
      zoomOffset: -1,
      userAgentPackageName: 'com.webspeople.app',
    );
  }
}