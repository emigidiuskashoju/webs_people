import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<bool> requestPermission() async {
    final enabled =
        await Geolocator.isLocationServiceEnabled();

    if (!enabled) {
      return false;
    }

    var permission =
        await Geolocator.checkPermission();

    if (permission ==
        LocationPermission.denied) {
      permission =
          await Geolocator.requestPermission();
    }

    if (permission ==
            LocationPermission.denied ||
        permission ==
            LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<Position> getCurrentPosition() async {
    final permission =
        await requestPermission();

    if (!permission) {
      throw Exception(
        'Location permission was not granted.',
      );
    }

    return Geolocator.getCurrentPosition();
  }
}