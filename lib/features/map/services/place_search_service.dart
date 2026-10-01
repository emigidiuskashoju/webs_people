import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/place.dart';

class PlaceSearchService {
  PlaceSearchService();

  static const String _baseUrl =
      'https://nominatim.openstreetmap.org/search';

  static const Map<String, String> _headers = {
  // This MUST identify your app specifically.
  // Format: AppName/Version (contact info)
  'User-Agent': 'WebsPeople/1.0 (contact: emigidiuskashoju@gmail.com)',
  'Accept': 'application/json',
  'Referer': 'https://github.com/emigidiuskashoju/webs_people',
};
  Timer? _debounce;
  int _requestCounter = 0;

  void searchDebounced({
    required String query,
    required void Function(List<Place> results) onResults,
    required void Function(Object error) onError,
    Duration debounce = const Duration(milliseconds: 450),
  }) {
    _debounce?.cancel();

    final trimmed = query.trim();

    if (trimmed.length < 3) {
      onResults(<Place>[]);
      return;
    }

    _debounce = Timer(debounce, () async {
      final myTicket = ++_requestCounter;
      try {
        final results = await _search(trimmed);
        if (myTicket != _requestCounter) return;
        onResults(results);
      } catch (e) {
        if (myTicket != _requestCounter) return;
        onError(e);
      }
    });
  }

  Future<List<Place>> _search(String query) async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'q': query,
        'format': 'json',
        'addressdetails': '0',
        'limit': '6',
        'accept-language': 'en',
      },
    );

    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Place search failed (${response.statusCode}).');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Unexpected place search response.');
    }

    return decoded
        .whereType<Map>()
        .map((item) => Place.fromNominatim(Map<String, dynamic>.from(item)))
        .where((place) =>
            place.position.latitude != 0 && place.position.longitude != 0)
        .toList();
  }

  /// Reverse-geocode a coordinate into a short human-readable label
  /// like "Dar es Salaam, Mabibo" (city + suburb).
  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse',
      ).replace(
        queryParameters: {
          'lat': latitude.toString(),
          'lon': longitude.toString(),
          'format': 'json',
          'zoom': '18',
          'addressdetails': '1',
          'accept-language': 'en',
        },
      );

      final response = await http.get(uri, headers: _headers);
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;

      final address = decoded['address'];
      if (address is! Map) {
        final display = decoded['display_name']?.toString() ?? '';
        if (display.isNotEmpty) {
          final parts = display
              .split(',')
              .map((p) => p.trim())
              .where((p) => p.isNotEmpty)
              .toList();
          if (parts.length >= 2) {
            return '${parts[1]}, ${parts[0]}';
          }
          return parts.isNotEmpty ? parts.first : null;
        }
        return null;
      }

      // Try, in order, to build "City, Suburb".
      final city = _firstNonEmpty([
        address['city'],
        address['town'],
        address['municipality'],
        address['village'],
        address['county'],
        address['state'],
      ]);

      final neighbourhood = _firstNonEmpty([
        address['suburb'],
        address['neighbourhood'],
        address['quarter'],
        address['city_district'],
        address['hamlet'],
        address['residential'],
      ]);

      if (city != null && neighbourhood != null) {
        return '$city, $neighbourhood';
      }
      if (city != null) return city;
      if (neighbourhood != null) return neighbourhood;

      // Fallback to display_name's first two parts.
      final display = decoded['display_name']?.toString() ?? '';
      if (display.isNotEmpty) {
        final parts = display
            .split(',')
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .toList();
        if (parts.length >= 2) {
          return '${parts[1]}, ${parts[0]}';
        }
        return parts.isNotEmpty ? parts.first : null;
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  String? _firstNonEmpty(List<dynamic> values) {
    for (final v in values) {
      final text = v?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  void dispose() {
    _debounce?.cancel();
    _debounce = null;
  }
}