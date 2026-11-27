import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/map/map_style_preference.dart';
import '../../core/map/mapbox_tile_layer.dart';
import '../../core/theme/webs_colors.dart';
import '../map/widgets/map_style_sheet.dart';
import '../map/widgets/photo_marker.dart';
import '../map/widgets/route_flow_dots.dart';
import 'bw_api.dart';
import 'bw_saved_deliveries.dart';

/// One Shopicky delivery on the Webs map.
///
/// The buyer (order code) and the seller (secure link from the email) see the
/// same order and positions as on the Shopicky website, so one person can
/// use the website and the other the Webs app.
class BwDeliveryScreen extends StatefulWidget {
  /// Buyer: the tracking code, e.g. SP-7Q3K9P.
  final String? code;

  /// Seller / admin: the secure order link from the Shopicky email.
  final String? link;

  const BwDeliveryScreen.buyer({super.key, required String this.code}) : link = null;
  const BwDeliveryScreen.seller({super.key, required String this.link}) : code = null;

  bool get isSeller => link != null;

  @override
  State<BwDeliveryScreen> createState() => _BwDeliveryScreenState();
}

class _BwDeliveryScreenState extends State<BwDeliveryScreen> {
  // Same pin colours as the Webs map and the Shopicky website
  static const Color _shopRing = Color(0xFF25D366);
  static const Color _shopFill = Color(0xFFE8F5E9);
  static const Color _buyerRing = Color(0xFFF57C00);
  static const Color _buyerFill = Color(0xFFFFF3E0);
  static const Color _courierRing = Color(0xFFD4AF37);
  static const Color _courierFill = Color(0xFFFFF8E1);
  static const Color _orange = Color(0xFFFF6B00);
  static const Color _navy = Color(0xFF0F2B5B);
  static const double _pin = 44;
  static const LatLng _darEsSalaam = LatLng(-6.7924, 39.2083);

  final MapController _map = MapController();
  final Distance _distance = const Distance();

  BwOrder? _order;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  bool _remembered = false;
  Timer? _poll;

  MapStyleKind _style = MapStyleKind.satelliteHd;
  bool _mapReady = false;
  bool _fitted = false;

  // My own live position while I share it
  StreamSubscription<Position>? _gps;
  LatLng? _me;
  DateTime _lastSent = DateTime(2000);
  String? _gpsNote;

  // Road route (re-requested only after moving 150 m or after a minute)
  List<LatLng> _route = const [];
  double? _routeMeters;
  double? _routeSeconds;
  bool _routeRoad = false;
  LatLng? _routeFrom;
  LatLng? _routeTo;
  DateTime _routeAt = DateTime(2000);

  bool get _sharing => _gps != null;

  @override
  void initState() {
    super.initState();
    MapStylePreference.load().then((s) {
      if (mounted) setState(() => _style = s);
    });
    _load();
    // Refresh so the other person's pin moves (website does the same)
    _poll = Timer.periodic(Duration(seconds: widget.isSeller ? 15 : 10), (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _gps?.cancel();
    _map.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ data

  Future<void> _load({bool quiet = false}) async {
    if (!quiet && _order == null) setState(() => _loading = true);
    try {
      final order = widget.isSeller ? await BwApi.bySellerLink(widget.link!) : await BwApi.byCode(widget.code!);
      if (!mounted) return;
      setState(() {
        _order = order;
        _error = null;
        _loading = false;
      });
      if (!_remembered) {
        _remembered = true;
        BwSavedDeliveries.remember(BwSavedDelivery(
          role: widget.isSeller ? 'seller' : 'buyer',
          key: widget.isSeller ? widget.link! : order.code,
          code: order.code,
          title: order.product,
          savedAt: DateTime.now(),
        ));
      }
      if (!order.trackable && _sharing) _stopSharing();
      _fit();
      _updateRoute();
    } on BwApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_order == null) _error = e.message;
      });
    }
  }

  BwPlace get _shop => _order!.shop;

  BwPlace get _buyer => !widget.isSeller && _me != null
      ? _order!.buyer.copyWith(point: _me, live: true, updated: 'just now')
      : _order!.buyer;

  BwPlace? get _courier => widget.isSeller && _me != null
      ? (_order!.courier ?? const BwPlace(name: 'You')).copyWith(point: _me, live: true, moving: true, updated: 'just now', name: 'You')
      : _order!.courier;

  // ------------------------------------------------------------------ map

  void _fit({bool force = false}) {
    if (!_mapReady || _order == null || (_fitted && !force)) return;
    final pts = [_shop.point, _buyer.point, _courier?.point].whereType<LatLng>().toList();
    if (pts.isEmpty) return;
    _fitted = true;
    if (pts.length == 1) {
      _map.move(pts.first, 15);
    } else {
      _map.fitCamera(CameraFit.coordinates(coordinates: pts, padding: const EdgeInsets.all(70), maxZoom: 16));
    }
  }

  Future<void> _updateRoute() async {
    if (_order == null) return;
    final from = _courier?.point ?? _shop.point;
    final to = _buyer.point;
    if (from == null || to == null) {
      if (_route.isNotEmpty) setState(() => _route = const []);
      return;
    }
    final stale = _routeFrom == null ||
        _distance(_routeFrom!, from) > 150 ||
        _distance(_routeTo!, to) > 30 ||
        DateTime.now().difference(_routeAt).inSeconds > 60;
    if (!stale) return;
    _routeFrom = from;
    _routeTo = to;
    _routeAt = DateTime.now();

    var points = [from, to];
    var meters = _distance(from, to).toDouble();
    double? seconds;
    var road = false;
    try {
      final url = Uri.parse('https://api.mapbox.com/directions/v5/mapbox/driving/'
          '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
          '?geometries=geojson&overview=full&access_token=$kMapboxAccessToken');
      final res = await http.get(url).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final routes = (jsonDecode(res.body) as Map<String, dynamic>)['routes'];
        if (routes is List && routes.isNotEmpty) {
          final r = routes.first as Map<String, dynamic>;
          final coords = (r['geometry'] as Map<String, dynamic>)['coordinates'] as List;
          points = coords.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
          meters = (r['distance'] as num).toDouble();
          seconds = (r['duration'] as num).toDouble();
          road = true;
        }
      }
    } catch (_) {
      // Offline: keep the straight line
    }
    if (!mounted) return;
    setState(() {
      _route = points;
      _routeMeters = meters;
      _routeSeconds = seconds;
      _routeRoad = road;
    });
  }

  Future<void> _pickStyle() async {
    final picked = await MapStyleSheet.show(context, current: _style);
    if (picked == null || !mounted) return;
    setState(() => _style = picked);
    await MapStylePreference.save(picked);
  }

  Marker _pinAt(LatLng point, Widget child) => Marker(
        point: point,
        width: _pin,
        height: _pin * 1.25,
        alignment: Alignment.topCenter, // the tail tip sits on the point
        child: child,
      );

  List<Marker> _markers() {
    final markers = <Marker>[];
    final shop = _shop;
    final buyer = _buyer;
    final courier = _courier;
    if (shop.point != null) {
      markers.add(_pinAt(
        shop.point!,
        PhotoMarker(photoUrl: shop.photoUrl, fallbackInitial: shop.name, ringColor: _shopRing, fillColor: _shopFill, size: _pin),
      ));
    }
    if (buyer.point != null) {
      markers.add(_pinAt(
        buyer.point!,
        const PhotoMarker(fallbackInitial: '📍', ringColor: _buyerRing, fillColor: _buyerFill, size: _pin),
      ));
    }
    if (courier?.point != null) {
      final pin = PhotoMarker(
        photoUrl: courier!.photoUrl,
        fallbackInitial: courier.photoUrl == null ? '🚚' : courier.name,
        ringColor: _courierRing,
        fillColor: _courierFill,
        size: _pin,
      );
      markers.add(_pinAt(courier.point!, courier.live ? pin : Opacity(opacity: 0.6, child: pin)));
    }
    return markers;
  }

  // ------------------------------------------------------------------ my location

  Future<bool> _locationAllowed() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _snack('Turn on location (GPS) first.');
      return false;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      _snack('Allow location for Webs so the other person can see where you are.');
      return false;
    }
    return true;
  }

  Future<LatLng?> _currentPosition() async {
    if (!await _locationAllowed()) return null;
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 12)),
      );
      return LatLng(p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<void> _startSharing() async {
    if (_sharing || !await _locationAllowed()) return;
    if (!mounted) return;
    setState(() => _gpsNote = 'Waiting for GPS…');
    _gps = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).listen(
      _onPosition,
      onError: (_) {
        if (mounted) setState(() => _gpsNote = 'GPS problem — check that location is on.');
      },
    );
    setState(() {});
  }

  void _stopSharing() {
    _gps?.cancel();
    _gps = null;
    if (mounted) {
      setState(() {
        _gpsNote = null;
        _me = null;
      });
    }
  }

  Future<void> _onPosition(Position p) async {
    if (!mounted) return;
    final here = LatLng(p.latitude, p.longitude);
    setState(() => _me = here);
    _updateRoute();

    final every = Duration(seconds: widget.isSeller ? 8 : 15);
    if (DateTime.now().difference(_lastSent) < every) return;
    _lastSent = DateTime.now();
    try {
      if (widget.isSeller) {
        await BwApi.sellerAction(widget.link!, 'location', at: here);
      } else {
        await BwApi.sendBuyerLocation(_order!.code, here);
      }
      if (mounted) setState(() => _gpsNote = 'Last sent ${TimeOfDay.now().format(context)}');
    } on BwApiException catch (e) {
      _lastSent = DateTime(2000); // try again with the next position
      if (e.message.contains('no longer')) {
        _stopSharing();
        _load();
      } else if (mounted) {
        setState(() => _gpsNote = e.message);
      }
    }
  }

  // ------------------------------------------------------------------ seller actions

  Future<void> _act(String action, {LatLng? at}) async {
    setState(() => _busy = true);
    try {
      _snack(await BwApi.sellerAction(widget.link!, action, at: at));
      await _load(quiet: true);
    } on BwApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Accept also shares where I am now, so the buyer sees me on the map.
  Future<void> _accept({bool andDeliver = false}) async {
    setState(() => _busy = true);
    final here = await _currentPosition();
    await _act('accept', at: here);
    if (andDeliver && _order?.status == 'accepted') await _outForDelivery();
  }

  Future<void> _outForDelivery() async {
    final here = _me ?? await _currentPosition();
    await _act('start_delivery', at: here);
    await _startSharing();
  }

  Future<void> _decline() async {
    if (await _confirm('Decline this order?', 'The buyer will be told it was declined.')) {
      await _act('decline');
    }
  }

  Future<void> _delivered() async {
    if (await _confirm('Mark as delivered?', 'The buyer gets an email and live sharing stops.')) {
      _stopSharing();
      await _act('delivered');
    }
  }

  // ------------------------------------------------------------------ helpers

  Future<bool> _confirm(String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Yes')),
        ],
      ),
    );
    return ok == true;
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _open(String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok) _snack('Could not open $url');
  }

  static String _distanceText(double m) => m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} km' : '${m.round()} m';

  static String _durationText(double s) {
    final m = (s / 60).round().clamp(1, 100000);
    return m >= 60 ? '${m ~/ 60} h ${m % 60} min' : '$m min';
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return Scaffold(
      appBar: AppBar(
        title: Text(order == null ? 'Delivery' : 'Order ${order.code}'),
        actions: [
          IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: () => _load()),
        ],
      ),
      body: order == null
          ? (_loading ? const Center(child: CircularProgressIndicator()) : _errorView())
          : Column(
              children: [
                Expanded(child: _mapView()),
                _panel(order),
              ],
            ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_shipping_outlined, size: 56, color: _orange),
            const SizedBox(height: 12),
            Text(_error ?? 'Something went wrong.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => _load(), child: const Text('Try again')),
          ],
        ),
      ),
    );
  }

  Widget _mapView() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: _darEsSalaam,
            initialZoom: 12,
            onMapReady: () {
              _mapReady = true;
              _fit();
            },
          ),
          children: [
            MapboxTileLayer.forStyle(_style),
            if (_route.length >= 2)
              PolylineLayer(
                polylines: [Polyline(points: _route, strokeWidth: 6, color: WebsColors.primaryGreen)],
              ),
            // Golden dots flowing towards the buyer, like the Webs route
            if (_route.length >= 2) RouteFlowDotsLayer(route: _route),
            MarkerLayer(markers: _markers()),
          ],
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Column(
            children: [
              _roundButton(Icons.layers_outlined, 'Map style', _pickStyle),
              const SizedBox(height: 8),
              _roundButton(Icons.fit_screen_outlined, 'Show everyone', () => _fit(force: true)),
            ],
          ),
        ),
        Positioned(
          left: 8,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(6)),
            child: Text(_style.attribution, style: const TextStyle(fontSize: 10, color: Colors.black87)),
          ),
        ),
      ],
    );
  }

  Widget _roundButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: IconButton(tooltip: tooltip, icon: Icon(icon, color: _navy), onPressed: onTap),
    );
  }

  Widget _panel(BwOrder order) {
    final courier = _courier;
    final textLight = WebsColors.textLight(context);
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.48),
      decoration: BoxDecoration(
        color: WebsColors.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${order.quantity} × ${order.product}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: WebsColors.textDark(context)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _statusChip(order),
                ],
              ),
              const SizedBox(height: 6),
              if (order.trackable)
                Text(
                  courier == null
                      ? 'Waiting for the seller to share their location'
                      : courier.moving
                          ? '🚚 On the way · updated ${courier.updated ?? 'just now'}'
                          : "Seller's location · ${courier.updated ?? 'just now'}",
                  style: TextStyle(color: courier?.moving == true ? WebsColors.primaryGreen : textLight, fontWeight: FontWeight.w600),
                ),
              if (order.trackable && _routeMeters != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _routeSeconds != null
                        ? '${_durationText(_routeSeconds!)} · ${_distanceText(_routeMeters!)} ${_routeRoad ? 'by road' : 'away'}'
                        : 'About ${_distanceText(_routeMeters!)} away (straight line)',
                    style: TextStyle(color: textLight),
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  _legend(_shopRing, 'Shop'),
                  _legend(_buyerRing, widget.isSeller ? 'Buyer' : 'You'),
                  _legend(_courierRing, widget.isSeller ? 'You / delivery' : 'Seller'),
                ],
              ),
              const SizedBox(height: 12),
              ...(widget.isSeller ? _sellerActions(order) : _buyerActions(order)),
              if (_gpsNote != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_gpsNote!, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: textLight)),
                ),
              TextButton.icon(
                onPressed: () => _open(widget.isSeller ? widget.link! : BwApi.websiteTrackUrl(order.code)),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Open on the Shopicky website'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legend(Color c, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: WebsColors.textLight(context))),
        ],
      );

  Widget _statusChip(BwOrder order) {
    final colors = <String, Color>{
      'pending': Colors.amber.shade700,
      'accepted': Colors.blue.shade700,
      'out_for_delivery': Colors.purple.shade600,
      'delivered': Colors.green.shade700,
      'cancelled': Colors.red.shade700,
    };
    final c = colors[order.status] ?? Colors.grey.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(order.statusLabel, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _bigButton(String label, Color color, VoidCallback? onTap, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: _busy ? null : onTap,
        icon: Icon(icon ?? Icons.check, size: 20),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _sharingBox(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.10),
        border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.my_location, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600))),
          TextButton(onPressed: _stopSharing, child: const Text('Stop')),
        ],
      ),
    );
  }

  List<Widget> _buyerActions(BwOrder order) {
    switch (order.status) {
      case 'unverified':
        return [
          const Text('Confirm your email on Shopicky to send this order to the seller.'),
          _bigButton('Enter my code on Shopicky', _orange, () => _open('$kShopickyUrl/orders/${order.code}/verify'), icon: Icons.mark_email_read_outlined),
        ];
      case 'pending':
        return [const Text('Waiting for the seller to accept your order. You will get an email.')];
      case 'delivered':
        return [const Text('🎉 Delivered. Thank you for shopping on Shopicky!')];
      case 'cancelled':
        return [const Text('This order was cancelled.')];
    }
    return [
      if (_sharing)
        _sharingBox('The seller can see where you are')
      else
        _bigButton('Share my live location with the seller', _buyerRing, _startSharing, icon: Icons.share_location),
    ];
  }

  List<Widget> _sellerActions(BwOrder order) {
    final buyerPhone = order.buyerPhone?.replaceAll(RegExp(r'\s'), '');
    final buyerSpot = order.buyer.point;
    final contact = Row(
      children: [
        if (buyerSpot != null)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _open('https://www.google.com/maps/dir/?api=1&destination=${buyerSpot.latitude},${buyerSpot.longitude}&travelmode=driving'),
              icon: const Icon(Icons.directions, size: 18),
              label: const Text('Directions'),
            ),
          ),
        if (buyerSpot != null && buyerPhone != null) const SizedBox(width: 8),
        if (buyerPhone != null && buyerPhone.isNotEmpty)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _open('tel:$buyerPhone'),
              icon: const Icon(Icons.call, size: 18),
              label: const Text('Call buyer'),
            ),
          ),
      ],
    );

    switch (order.status) {
      case 'pending':
        return [
          const Text('Accepting shares where you are now with the buyer.'),
          _bigButton('Accept & go out for delivery', _orange, () => _accept(andDeliver: true), icon: Icons.local_shipping),
          _bigButton('Accept', Colors.green.shade700, () => _accept(), icon: Icons.check_circle_outline),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TextButton(onPressed: _busy ? null : _decline, child: const Text('Decline this order', style: TextStyle(color: Colors.red))),
          ),
        ];
      case 'accepted':
      case 'out_for_delivery':
        return [
          if (_sharing)
            _sharingBox('Sharing your live location — keep Webs open')
          else
            _bigButton(
              order.status == 'accepted' ? 'Out for delivery — share my live location' : 'Share my live location again',
              _orange,
              order.status == 'accepted' ? _outForDelivery : _startSharing,
              icon: Icons.local_shipping,
            ),
          const SizedBox(height: 8),
          contact,
          _bigButton('Mark as delivered', Colors.green.shade700, _delivered, icon: Icons.task_alt),
        ];
      case 'delivered':
        return [const Text('✅ Delivered. Thank you!')];
      case 'cancelled':
        return [const Text('This order was declined / cancelled.')];
    }
    return [Text(order.statusLabel)];
  }
}
