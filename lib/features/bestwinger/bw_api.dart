import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// The Shoopicky website. It is the single source of truth for orders and
/// delivery positions, so a buyer on the website and a seller in the Webs app
/// (or the other way round) always see the same map.
const String kShoopickyUrl = 'https://shoopicky.webzapp.org';

/// Secure seller links may come from the new address or from older emails.
const Set<String> _bestWingerHosts = {'shoopicky.webzapp.org', 'bestwinger.webzapp.org'};

/// A place on the delivery map: the shop, the buyer or the seller on the way.
class BwPlace {
  final String name;
  final String? photoUrl;
  final LatLng? point;
  final String? updated; // e.g. "2 minutes ago"
  final bool live;
  final bool moving;

  const BwPlace({
    required this.name,
    this.photoUrl,
    this.point,
    this.updated,
    this.live = false,
    this.moving = false,
  });

  factory BwPlace.fromJson(Object? raw, String fallbackName) {
    final j = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
    final lat = _toDouble(j['lat']);
    final lng = _toDouble(j['lng']);
    return BwPlace(
      name: (j['name'] as String?)?.trim().isNotEmpty == true ? j['name'] as String : fallbackName,
      photoUrl: j['photo_url'] as String?,
      point: lat != null && lng != null ? LatLng(lat, lng) : null,
      updated: j['updated'] as String?,
      live: j['live'] == true,
      moving: j['moving'] == true,
    );
  }

  BwPlace copyWith({LatLng? point, bool? live, bool? moving, String? updated, String? name}) => BwPlace(
        name: name ?? this.name,
        photoUrl: photoUrl,
        point: point ?? this.point,
        updated: updated ?? this.updated,
        live: live ?? this.live,
        moving: moving ?? this.moving,
      );
}

/// One Shoopicky order as the website shows it.
class BwOrder {
  final String code;
  final String product;
  final String status; // unverified, pending, accepted, out_for_delivery, delivered, cancelled
  final String statusLabel;
  final bool trackable;
  final int quantity;
  final num total;
  final String? buyerName;
  final String? buyerPhone;
  final String? shopName;
  final BwPlace shop;
  final BwPlace buyer;
  final BwPlace? courier;

  const BwOrder({
    required this.code,
    required this.product,
    required this.status,
    required this.statusLabel,
    required this.trackable,
    required this.quantity,
    required this.total,
    required this.shop,
    required this.buyer,
    this.courier,
    this.buyerName,
    this.buyerPhone,
    this.shopName,
  });

  factory BwOrder.fromJson(Map<String, dynamic> j) {
    final map = j['map'] is Map<String, dynamic> ? j['map'] as Map<String, dynamic> : const <String, dynamic>{};
    final courier = map['courier'];
    return BwOrder(
      code: j['code'] as String? ?? '',
      product: (j['product_name'] ?? j['product'] ?? 'Product') as String,
      status: j['status'] as String? ?? 'pending',
      statusLabel: j['status_label'] as String? ?? '',
      trackable: j['trackable'] == true,
      quantity: (j['quantity'] as num?)?.toInt() ?? 1,
      total: num.tryParse('${j['total_price'] ?? 0}') ?? 0,
      buyerName: j['buyer_name'] as String?,
      buyerPhone: j['buyer_phone'] as String?,
      shopName: j['shop'] is String ? j['shop'] as String : null,
      shop: BwPlace.fromJson(map['shop'], 'Shop'),
      buyer: BwPlace.fromJson(map['buyer'], 'Buyer'),
      courier: courier is Map<String, dynamic> ? BwPlace.fromJson(courier, 'Seller') : null,
    );
  }
}

class BwApiException implements Exception {
  final String message;
  const BwApiException(this.message);
  @override
  String toString() => message;
}

class BwApi {
  static const Map<String, String> _headers = {
    'Accept': 'application/json',
    'X-Requested-With': 'XMLHttpRequest',
  };
  static const Duration _timeout = Duration(seconds: 20);

  /// Buyer: look an order up by its tracking code (BW-XXXXXX).
  static Future<BwOrder> byCode(String code) async {
    final uri = Uri.parse('$kShoopickyUrl/track').replace(queryParameters: {'code': normalizeCode(code)});
    final res = await _send(() => http.get(uri, headers: _headers));
    final order = (jsonDecode(res.body) as Map<String, dynamic>)['order'];
    if (order is! Map<String, dynamic>) throw const BwApiException('No order found with that code.');
    return BwOrder.fromJson(order);
  }

  /// Seller / admin: the secure link from the Shoopicky email.
  static Future<BwOrder> bySellerLink(String link) async {
    final res = await _send(() => http.get(Uri.parse(link), headers: _headers));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return BwOrder.fromJson(body['order'] as Map<String, dynamic>);
  }

  /// Buyer's live location (by order code).
  static Future<void> sendBuyerLocation(String code, LatLng p) async {
    await _send(() => http.post(
          Uri.parse('$kShoopickyUrl/track/location'),
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: jsonEncode({'code': normalizeCode(code), 'lat': p.latitude, 'lng': p.longitude}),
        ));
  }

  /// Seller / admin actions: accept, decline, start_delivery, location, delivered.
  static Future<String> sellerAction(String link, String action, {LatLng? at}) async {
    final res = await _send(() => http.post(
          Uri.parse(link),
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'action': action,
            if (at != null) 'lat': at.latitude,
            if (at != null) 'lng': at.longitude,
          }),
        ));
    final body = jsonDecode(res.body);
    return body is Map && body['message'] is String ? body['message'] as String : 'Done.';
  }

  /// "bw-3flkne " -> "BW-3FLKNE"
  static String normalizeCode(String code) => code.trim().toUpperCase();

  /// Only secure order links from the Shoopicky website are accepted.
  static bool isSellerLink(String link) {
    final uri = Uri.tryParse(link.trim());
    return uri != null &&
        uri.scheme == 'https' &&
        _bestWingerHosts.contains(uri.host) &&
        RegExp(r'^/orders/\d+/respond$').hasMatch(uri.path) &&
        uri.queryParameters.containsKey('signature');
  }

  /// The same order on the website.
  static String websiteTrackUrl(String code) =>
      Uri.parse('$kShoopickyUrl/track').replace(queryParameters: {'code': normalizeCode(code), 'map': '1'}).toString();

  static Future<http.Response> _send(Future<http.Response> Function() call) async {
    http.Response res;
    try {
      res = await call().timeout(_timeout);
    } catch (_) {
      throw const BwApiException('Could not reach Shoopicky. Check your internet and try again.');
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return res;
    switch (res.statusCode) {
      case 404:
        throw const BwApiException('No order found with that code.');
      case 403:
        throw const BwApiException('This link has expired. Open the latest Shoopicky email again.');
      case 409:
        throw const BwApiException('This order is no longer being delivered.');
      case 422:
        throw const BwApiException('Shoopicky could not accept that. Please try again.');
      case 429:
        throw const BwApiException('Too many tries — wait a minute and try again.');
      default:
        throw BwApiException('Shoopicky is not available right now (${res.statusCode}).');
    }
  }
}

double? _toDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}
