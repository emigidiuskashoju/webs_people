import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../core/background/background_location_service.dart';
import '../../core/storage/auth_storage.dart';
import '../../core/theme/webs_colors.dart';
import 'models/route_point.dart';
import 'models/location_request.dart';
import 'models/custom_route.dart';
import 'models/place.dart';
import 'services/location_request_service.dart';
import 'services/map_location_service.dart';
import 'services/custom_route_progress.dart';
import 'services/custom_route_service.dart';
import 'services/place_search_service.dart';
import 'services/place_routing_service.dart';
import 'widgets/location_ticker.dart';
import 'widgets/place_search_card.dart';

class MapScreen extends StatefulWidget {
  final int currentUserId;
  final int userId;
  final String name;

  const MapScreen({
    super.key,
    required this.currentUserId,
    required this.userId,
    required this.name,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // ==================================================================
  // BACKEND API BASE — used by the background service
  // ==================================================================
  //
  // Replace the value below with your actual API base URL.
  // It must match the base used by ApiClient / ApiEndpoints.
  //
 static const String _bgApiBase = 'http://134.209.65.175/api/v1';

  final MapController _mapController = MapController();
  final MapLocationService _locationService = MapLocationService();
  final LocationRequestService _requestService = LocationRequestService();
  final CustomRouteService _customRouteService = CustomRouteService();
  final PlaceSearchService _placeSearchService = PlaceSearchService();
  final PlaceRoutingService _placeRoutingService = PlaceRoutingService();
  final TextEditingController _codeController = TextEditingController();

  // ===== Place search =====
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<Place> _searchResults = <Place>[];
  bool _searchLoading = false;
  String? _searchError;

  Place? _activeDestination;
  List<LatLng> _destinationRouteGeometry = <LatLng>[];
  double? _destinationRemainingMeters;
  double? _destinationRemainingSeconds;
  LatLng? _lastRouteOrigin;

  Timer? _destinationRecalcTimer;

  // ===== Tickers =====
  LocationTickerData _tickerData = const LocationTickerData();
  Timer? _reverseGeocodeTimer;
  String? _lastTickerPlaceLabel;

  LocationTickerData _otherTickerData = const LocationTickerData();
  Timer? _otherReverseGeocodeTimer;
  String? _lastOtherTickerPlaceLabel;

  // ===== Other-user polling =====
  Timer? _otherLocationPollTimer;
  DateTime? _lastOtherFetchAt;

  // ===== Freshness badge refresh =====
  Timer? _freshnessTickTimer;

  // ===== State =====
  StreamSubscription<Position>? _locationSubscription;
  LatLng? _currentLocation;
  LatLng? _otherLocation;
  double? _otherAccuracy;
  DateTime? _otherLocationUpdatedAt;
  bool _loading = true;
  bool _requesting = false;
  bool _refreshingOther = false;
  String? _error;

  String? _dailyCode;
  DateTime? _dailyCodeExpiresAt;
  Timer? _dailyCodeTimer;
  bool _dailyCodeLoading = true;

  LocationRequest? _activeRequest;
  List<RoutePoint> _routePoints = [];
  List<LatLng> _routeGeometry = [];
  bool _routeLoading = false;

  Timer? _customRouteTimer;
  CustomRoute? _customRoute;
  List<LatLng> _customRouteRemainingPoints = [];
  double? _customRouteRemainingDistance;
  bool _customRouteMode = false;
  bool _customRouteGenerating = false;

  static LatLng? _cachedLastPosition;

  @override
  void initState() {
    super.initState();
    _initialize();

    _customRouteTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadSharedCustomRoute(silent: true),
    );

    _destinationRecalcTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _maybeRecalcDestinationRoute(),
    );

    _reverseGeocodeTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refreshTickerPlaceLabel(),
    );

    _otherReverseGeocodeTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refreshOtherTickerPlaceLabel(),
    );

    _otherLocationPollTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _pollOtherLocation(),
    );

    _freshnessTickTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _customRouteTimer?.cancel();
    _destinationRecalcTimer?.cancel();
    _reverseGeocodeTimer?.cancel();
    _otherReverseGeocodeTimer?.cancel();
    _otherLocationPollTimer?.cancel();
    _freshnessTickTimer?.cancel();
    _locationSubscription?.cancel();
    _dailyCodeTimer?.cancel();
    _codeController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _placeSearchService.dispose();
    _locationService.dispose();
    super.dispose();
  }

  // ==================================================================
  // INITIALIZATION
  // ==================================================================

  Future<void> _initialize() async {
    if (!mounted) return;

    setState(() {
      _loading = false;
      _currentLocation = _cachedLastPosition;
    });

    unawaited(
      _loadCurrentLocation().catchError((e) {
        if (mounted) setState(() => _error = _cleanError(e));
      }),
    );

    unawaited(
      _loadDailyCode().catchError((e) {
        if (mounted) setState(() => _error = _cleanError(e));
      }),
    );

    unawaited(
      _loadConversationRequest().catchError((e) {
        if (mounted) setState(() => _error = _cleanError(e));
      }),
    );

    unawaited(
      _startTracking().catchError((e) {
        if (mounted) setState(() => _error = _cleanError(e));
      }),
    );
  }

  void _scheduleDailyCodeRefresh() {
    _dailyCodeTimer?.cancel();
    final expiresAt = _dailyCodeExpiresAt;
    if (expiresAt == null) return;
    final delay = expiresAt.difference(DateTime.now());
    if (delay.isNegative) {
      _loadDailyCode();
      return;
    }
    _dailyCodeTimer = Timer(delay + const Duration(seconds: 1), () async {
      await _loadDailyCode();
      if (mounted) _scheduleDailyCodeRefresh();
    });
  }

  String _cleanError(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  Future<void> _loadCurrentLocation() async {
    final position = await _locationService.getCurrentPosition();
    final location = LatLng(position.latitude, position.longitude);
    if (!mounted) return;

    _cachedLastPosition = location;
    setState(() => _currentLocation = location);
    _updateTickerFromPosition(position);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(location, 16);
    });

    _refreshTickerPlaceLabel();
  }

  Future<void> _startTracking() async {
    await _locationSubscription?.cancel();
    _locationSubscription =
        _locationService.startTracking().listen(_handleLocalPosition);
  }

  Future<void> _handleLocalPosition(Position position) async {
    final location = LatLng(position.latitude, position.longitude);
    if (!mounted) return;

    _cachedLastPosition = location;
    setState(() => _currentLocation = location);

    _updateTickerFromPosition(position);
    _updateCustomRouteProgress(location);
    _trimDestinationRoute(location);

    final request = _activeRequest;
    if (request == null || !request.isAccepted) return;

    try {
      await _requestService
          .updateLocation(
            requestId: request.id,
            latitude: position.latitude,
            longitude: position.longitude,
            accuracy: position.accuracy,
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  // ==================================================================
  // BACKGROUND SERVICE STARTER
  // ==================================================================
  //
  // Called once the location request becomes "accepted".
  //
  // This starts a native foreground service that keeps
  // uploading the user's location even after the app is
  // closed, as long as the phone has internet.

  Future<void> _startBackgroundUploads({required int requestId}) async {
    try {
      final token = await AuthStorage().getToken();
      if (token == null || token.isEmpty) return;

      // Ask for background permission first (Android 10+).
      final currentPermission = await Geolocator.checkPermission();

      if (currentPermission == LocationPermission.whileInUse) {
        // The user granted "while using the app" but not
        // "always". Request the stronger permission.
        await Geolocator.requestPermission();
      }

      await BackgroundLocationService.instance.start(
        token: token,
        apiBase: _bgApiBase,
        requestId: requestId,
      );

      debugPrint('BG: background uploads started for request $requestId');
    } catch (e) {
      debugPrint('BG: failed to start: $e');
    }
  }

  // ==================================================================
  // TICKERS
  // ==================================================================

  void _updateTickerFromPosition(Position position) {
    setState(() {
      _tickerData = LocationTickerData(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        speedMetersPerSecond: position.speed,
        address: _lastTickerPlaceLabel,
      );
    });
  }

  Future<void> _refreshTickerPlaceLabel() async {
    final loc = _currentLocation;
    if (loc == null) return;

    final label = await _placeSearchService.reverseGeocode(
      latitude: loc.latitude,
      longitude: loc.longitude,
    );

    if (!mounted || label == null) return;

    setState(() {
      _lastTickerPlaceLabel = label;
      _tickerData = LocationTickerData(
        latitude: _tickerData.latitude,
        longitude: _tickerData.longitude,
        accuracyMeters: _tickerData.accuracyMeters,
        speedMetersPerSecond: _tickerData.speedMetersPerSecond,
        address: label,
      );
    });
  }

  void _updateOtherTicker() {
    final loc = _otherLocation;
    if (loc == null) {
      setState(() {
        _otherTickerData = const LocationTickerData();
        _lastOtherTickerPlaceLabel = null;
      });
      return;
    }

    setState(() {
      _otherTickerData = LocationTickerData(
        latitude: loc.latitude,
        longitude: loc.longitude,
        accuracyMeters: _otherAccuracy,
        speedMetersPerSecond: null,
        address: _lastOtherTickerPlaceLabel,
      );
    });

    if (_lastOtherTickerPlaceLabel == null) {
      _refreshOtherTickerPlaceLabel();
    }
  }

  Future<void> _refreshOtherTickerPlaceLabel() async {
    final loc = _otherLocation;
    if (loc == null) return;

    final label = await _placeSearchService.reverseGeocode(
      latitude: loc.latitude,
      longitude: loc.longitude,
    );

    if (!mounted || label == null) return;

    setState(() {
      _lastOtherTickerPlaceLabel = label;
      _otherTickerData = LocationTickerData(
        latitude: loc.latitude,
        longitude: loc.longitude,
        accuracyMeters: _otherAccuracy,
        speedMetersPerSecond: null,
        address: label,
      );
    });
  }

  // ==================================================================
  // POLL THE OTHER PERSON'S LOCATION
  // ==================================================================

  Future<void> _pollOtherLocation() async {
    if (!mounted) return;

    final request = _activeRequest;
    if (request == null || !request.isAccepted) return;

    if (_refreshingOther) return;

    try {
      _refreshingOther = true;

      final location = await _requestService
          .getLocation(request.id)
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (location == null) return;

      _lastOtherFetchAt = DateTime.now();

      final position = LatLng(location.latitude, location.longitude);

      setState(() {
        _otherLocation = position;
        _otherAccuracy = location.accuracy;
        _otherLocationUpdatedAt = location.updatedAt;
      });

      _updateOtherTicker();
    } catch (_) {
    } finally {
      _refreshingOther = false;
    }
  }

  // ==================================================================
  // FRESHNESS HELPERS
  // ==================================================================

  Duration? get _otherStaleness {
    final updated = _otherLocationUpdatedAt;
    if (updated == null) return null;
    return DateTime.now().difference(updated);
  }

  String _formatStaleness(Duration d) {
    if (d.inSeconds < 30) return 'LIVE';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  Color _stalenessColor(Duration? d) {
    if (d == null) return Colors.grey.shade700;
    if (d.inSeconds < 30) return const Color(0xFF25D366);
    if (d.inMinutes < 5) return Colors.orange.shade700;
    if (d.inHours < 1) return Colors.orange.shade800;
    if (d.inHours < 24) return Colors.red.shade700;
    return Colors.grey.shade700;
  }

  // ==================================================================
  // PLACE SEARCH
  // ==================================================================

  void _onSearchQueryChanged(String query) {
    _placeSearchService.searchDebounced(
      query: query,
      onResults: (results) {
        if (!mounted) return;
        setState(() {
          _searchResults = results;
          _searchLoading = false;
          _searchError = null;
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _searchResults = <Place>[];
          _searchLoading = false;
          _searchError = _cleanError(e);
        });
      },
    );

    if (!mounted) return;
    setState(() {
      _searchLoading = query.trim().length >= 3;
      _searchError = null;
    });
  }

  Future<void> _selectPlace(Place place) async {
    _searchFocus.unfocus();
    setState(() {
      _activeDestination = place;
      _searchResults = <Place>[];
      _searchController.text = place.name;
    });
    await _buildDestinationRoute(force: true);
  }

  Future<void> _buildDestinationRoute({bool force = false}) async {
    final destination = _activeDestination;
    final origin = _currentLocation;
    if (destination == null || origin == null) return;

    if (!force && _lastRouteOrigin != null) {
      final moved = const Distance().as(
        LengthUnit.Meter,
        _lastRouteOrigin!,
        origin,
      );
      if (moved < 25) return;
    }

    final result = await _placeRoutingService.fetchRoute(
      from: origin,
      to: destination.position,
    );

    if (!mounted || result == null) return;

    setState(() {
      _destinationRouteGeometry = result.geometry;
      _destinationRemainingMeters = result.distanceMeters;
      _destinationRemainingSeconds = result.durationSeconds;
      _lastRouteOrigin = origin;
    });

    if (result.geometry.length >= 2) {
      final bounds = LatLngBounds.fromPoints(result.geometry);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.fromLTRB(40, 100, 40, 260),
        ),
      );
    }
  }

  void _maybeRecalcDestinationRoute() {
    if (_activeDestination == null) return;
    if (_currentLocation == null) return;

    final lastOrigin = _lastRouteOrigin;
    if (lastOrigin == null) {
      _buildDestinationRoute(force: true);
      return;
    }

    final deviation = const Distance().as(
      LengthUnit.Meter,
      lastOrigin,
      _currentLocation!,
    );

    if (deviation > 60) {
      _buildDestinationRoute(force: true);
    }
  }

  void _trimDestinationRoute(LatLng currentPosition) {
    if (_destinationRouteGeometry.length < 2) return;

    double bestDistance = double.infinity;
    int bestIndex = 0;

    for (int i = 0; i < _destinationRouteGeometry.length; i++) {
      final d = const Distance().as(
        LengthUnit.Meter,
        currentPosition,
        _destinationRouteGeometry[i],
      );
      if (d < bestDistance) {
        bestDistance = d;
        bestIndex = i;
      }
    }

    if (bestDistance > 50) return;
    if (bestIndex == 0) return;

    final remaining = _destinationRouteGeometry.sublist(bestIndex);

    double remainingDistance = 0;
    for (int i = 0; i < remaining.length - 1; i++) {
      remainingDistance += const Distance().as(
        LengthUnit.Meter,
        remaining[i],
        remaining[i + 1],
      );
    }

    final totalOriginal = _destinationRemainingMeters ?? 0;
    final speedFactor =
        totalOriginal > 0 ? (remainingDistance / totalOriginal) : 1.0;

    setState(() {
      _destinationRouteGeometry = remaining;
      _destinationRemainingMeters = remainingDistance;
      _destinationRemainingSeconds =
          (_destinationRemainingSeconds ?? 0) * speedFactor;
    });
  }

  void _clearDestination() {
    _searchController.clear();
    setState(() {
      _activeDestination = null;
      _destinationRouteGeometry = <LatLng>[];
      _destinationRemainingMeters = null;
      _destinationRemainingSeconds = null;
      _lastRouteOrigin = null;
      _searchResults = <Place>[];
      _searchError = null;
      _searchLoading = false;
    });
  }

  // ==================================================================
  // CONVERSATION LOCATION REQUEST
  // ==================================================================

  Future<void> _loadConversationRequest() async {
    try {
      final requests = await _requestService
          .getConversationRequests(widget.userId)
          .timeout(const Duration(seconds: 10));

      if (requests.isEmpty) {
        if (mounted) setState(() => _activeRequest = null);
        return;
      }

      final active = requests.firstWhere(
        (r) => r.isPending || r.isAccepted,
        orElse: () => requests.first,
      );

      if (!mounted) return;

      setState(() {
        _activeRequest = active;

        final other = active.otherLocation(widget.currentUserId);

        if (other != null) {
          _otherLocation = LatLng(other.latitude, other.longitude);
          _otherAccuracy = other.accuracy;
          _otherLocationUpdatedAt = other.updatedAt;
        }
      });

      _updateOtherTicker();

      if (active.isAccepted) {
        // --------------------------------------------------------
        // Start the native background service. From this point on,
        // the phone will keep uploading its location even if the
        // user closes the app.
        // --------------------------------------------------------
        await _startBackgroundUploads(requestId: active.id);

        await _refreshOtherLocation();
        await _loadSharedCustomRoute();
      }
    } on TimeoutException {
      if (mounted) {
        setState(() => _error = 'Request took too long. Retrying...');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = _cleanError(e));
      }
    }
  }

  Future<void> _loadDailyCode() async {
    if (mounted) setState(() => _dailyCodeLoading = true);
    try {
      final result = await _requestService
          .generateDailyCode()
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      setState(() {
        _dailyCode = result.code;
        _dailyCodeExpiresAt = result.expiresAt;
        _dailyCodeLoading = false;
        _error = null;
      });
      _scheduleDailyCodeRefresh();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dailyCodeLoading = false;
        _error = _cleanError(e);
      });
    }
  }

  Future<void> _requestOtherPersonLocation() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      _showMessage('Enter the 6-digit location code.');
      return;
    }
    if (_requesting) return;
    setState(() {
      _requesting = true;
      _error = null;
    });
    try {
      final request = await _requestService
          .requestLocation(code)
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      setState(() => _activeRequest = request);
      _codeController.clear();
      _showMessage('Location request sent in Webs.');
    } catch (e) {
      if (!mounted) return;
      _showMessage(_cleanError(e));
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _refreshOtherLocation() async {
    final request = _activeRequest;
    if (request == null || !request.isAccepted) return;

    try {
      final location = await _requestService
          .getLocation(request.id)
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (location == null) {
        setState(() {
          _otherLocation = null;
          _otherAccuracy = null;
          _otherLocationUpdatedAt = null;
        });
        _updateOtherTicker();
        return;
      }

      final position = LatLng(location.latitude, location.longitude);

      setState(() {
        _otherLocation = position;
        _otherAccuracy = location.accuracy;
        _otherLocationUpdatedAt = location.updatedAt;
      });

      _updateOtherTicker();

      await _buildRouteToOtherPerson();
    } catch (_) {}
  }

  Future<void> _buildRouteToOtherPerson() async {
    final start = _currentLocation;
    final destination = _otherLocation;
    if (start == null || destination == null) return;

    setState(() => _routeLoading = true);
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson',
      );
      final response =
          await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return;
      final data = jsonDecode(response.body);
      final routes = data['routes'];
      if (routes is! List || routes.isEmpty) return;
      final geometry = routes.first['geometry'];
      final coordinates = geometry['coordinates'];
      if (coordinates is! List) return;
      final points = coordinates
          .whereType<List>()
          .where((item) => item.length >= 2)
          .map((item) => LatLng(
                (item[1] as num).toDouble(),
                (item[0] as num).toDouble(),
              ))
          .toList();

      if (!mounted) return;
      setState(() => _routeGeometry = points);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _routeLoading = false);
    }
  }

  // ==================================================================
  // CUSTOM ROUTE
  // ==================================================================

  Future<void> _loadSharedCustomRoute({bool silent = false}) async {
    final request = _activeRequest;
    if (request == null || !request.isAccepted) return;
    try {
      final route = await _customRouteService
          .getRoute(request.id)
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (route == null) {
        setState(() {
          _customRoute = null;
          _customRouteRemainingPoints = [];
          _customRouteRemainingDistance = null;
        });
        return;
      }
      setState(() {
        _customRoute = route;
        _customRouteRemainingPoints = route.positions;
        _customRouteRemainingDistance = route.totalDistanceMeters;
      });
      _updateCustomRouteProgress(_currentLocation);
    } catch (e) {
      if (!silent && mounted) _showMessage(_cleanError(e));
    }
  }

  void _updateCustomRouteProgress(LatLng? location) {
    final route = _customRoute;
    if (route == null || location == null || route.points.length < 2) return;
    final progress = CustomRouteProgressCalculator.calculate(
      currentLocation: location,
      route: route.positions,
    );
    if (!mounted) return;
    if (progress.isComplete) {
      setState(() {
        _customRouteRemainingPoints = [];
        _customRouteRemainingDistance = 0;
      });
      _showMessage('Custom route completed.');
      return;
    }
    setState(() {
      _customRouteRemainingPoints = progress.remainingPoints;
      _customRouteRemainingDistance = progress.remainingDistanceMeters;
    });
  }

  Future<void> _generateCustomRoute() async {
    if (_customRouteGenerating) return;
    final request = _activeRequest;
    if (request == null || !request.isAccepted) {
      _showMessage(
        'Location sharing must be accepted before creating a custom route.',
      );
      return;
    }
    if (_routePoints.length < 2) {
      _showMessage('Add at least 2 points to create a route.');
      return;
    }
    setState(() {
      _customRouteGenerating = true;
      _error = null;
    });
    try {
      final points = _routePoints
          .asMap()
          .entries
          .map((entry) => CustomRoutePoint(
                latitude: entry.value.position.latitude,
                longitude: entry.value.position.longitude,
                order: entry.key + 1,
              ))
          .toList();
      final route = await _customRouteService
          .createRoute(
            locationRequestId: request.id,
            points: points,
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      setState(() {
        _customRoute = route;
        _customRouteRemainingPoints = route.positions;
        _customRouteRemainingDistance = route.totalDistanceMeters;
        _customRouteMode = false;
        _routePoints = [];
      });
      _showMessage(
        'Custom route generated: ${_formatDistance(route.totalDistanceMeters)}',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _cleanError(e));
      _showMessage(_cleanError(e));
    } finally {
      if (!mounted) return;
      setState(() => _customRouteGenerating = false);
    }
  }

  void _startCustomRouteMode() {
    final request = _activeRequest;
    if (request == null || !request.isAccepted) {
      _showMessage('Accept location sharing first.');
      return;
    }
    setState(() {
      _customRouteMode = true;
      _routePoints = [];
    });
  }

  void _undoCustomRoutePoint() {
    if (_routePoints.isEmpty) return;
    setState(() {
      _routePoints = List<RoutePoint>.from(_routePoints)..removeLast();
    });
  }

  void _cancelCustomRouteMode() {
    setState(() {
      _customRouteMode = false;
      _routePoints = [];
    });
  }

  void _cancelCustomRouteLocally() {
    setState(() {
      _customRoute = null;
      _customRouteRemainingPoints = [];
      _customRouteRemainingDistance = null;
    });
  }

  void _addRoutePoint(LatLng position) {
    if (!_customRouteMode) return;
    final point = RoutePoint(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      position: position,
      order: _routePoints.length + 1,
    );
    setState(() => _routePoints.add(point));
  }

  void _moveToCurrentLocation() {
    final location = _currentLocation;
    if (location == null) return;
    _mapController.move(location, 17);
  }

  void _moveToOtherLocation() {
    final location = _otherLocation;
    if (location == null) {
      _showMessage('Other person\'s location is not available yet.');
      return;
    }
    _mapController.move(location, 17);
  }

  void _moveToDestination() {
    final destination = _activeDestination;
    if (destination == null) return;
    _mapController.move(destination.position, 15);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatExpiry(DateTime? dateTime) {
    if (dateTime == null) return '';
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return 'Changes automatically at $hour:$minute';
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  String _requestStatusText() {
    final request = _activeRequest;
    if (request == null) return 'No location request';
    switch (request.status) {
      case LocationRequestStatus.pending:
        return 'Location request pending';
      case LocationRequestStatus.accepted:
        return 'Location sharing active';
      case LocationRequestStatus.denied:
        return 'Location request denied';
      case LocationRequestStatus.expired:
        return 'Location request expired';
    }
  }

  // ==================================================================
  // MARKERS
  // ==================================================================

  Widget _buildCurrentLocationMarker() {
    return const Icon(Icons.my_location, size: 38, color: Colors.blue);
  }

  Widget _buildOtherLocationMarker() {
    final staleness = _otherStaleness;

    Color color;
    if (staleness == null) {
      color = Colors.red;
    } else if (staleness.inSeconds < 30) {
      color = Colors.red;
    } else if (staleness.inHours < 1) {
      color = Colors.orange.shade700;
    } else {
      color = Colors.grey.shade600;
    }

    return Icon(
      Icons.person_pin_circle,
      size: 48,
      color: color,
    );
  }

  Widget _buildDestinationMarker() {
    return const Icon(Icons.flag, size: 44, color: Colors.orange);
  }

  Widget _buildRoutePointMarker(int number) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: WebsColors.primaryGreen,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        number.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFreshnessBadge() {
    final staleness = _otherStaleness;
    final color = _stalenessColor(staleness);
    final text = staleness == null ? 'NO DATA' : _formatStaleness(staleness);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 1,
        ),
      ),
    );
  }

  // ==================================================================
  // INFO PANEL
  // ==================================================================

  Widget _buildInfoPanel() {
    return DraggableScrollableSheet(
      initialChildSize: 0.42,
      minChildSize: 0.20,
      maxChildSize: 0.85,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: WebsColors.surface(context),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: WebsColors.shadow(context),
                blurRadius: 12,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: WebsColors.textLight(context)
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Location sharing',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: WebsColors.textDark(context),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _requestStatusText(),
                style: TextStyle(color: WebsColors.textLight(context)),
              ),
              const SizedBox(height: 16),
              _buildDailyCodeCard(),
              const SizedBox(height: 12),
              _buildRequestCard(),
              const SizedBox(height: 12),
              _buildSharedLocationCard(),
              const SizedBox(height: 12),
              _buildCustomRouteCard(),
              const SizedBox(height: 12),
              PlaceSearchCard(
                controller: _searchController,
                focusNode: _searchFocus,
                isLoading: _searchLoading,
                results: _searchResults,
                error: _searchError,
                hasActiveDestination: _activeDestination != null,
                activeDestinationName: _activeDestination?.name,
                remainingDistanceMeters: _destinationRemainingMeters,
                remainingDurationSeconds: _destinationRemainingSeconds,
                onQueryChanged: _onSearchQueryChanged,
                onPlaceSelected: _selectPlace,
                onClear: _clearDestination,
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WebsColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: WebsColors.shadow(context),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: WebsColors.border(context), width: 2),
      ),
      child: child,
    );
  }

  Widget _buildDailyCodeCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My location code',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: WebsColors.textDark(context),
            ),
          ),
          const SizedBox(height: 8),
          if (_dailyCodeLoading)
            Text(
              'Loading your daily location code...',
              style: TextStyle(color: WebsColors.textLight(context)),
            )
          else if (_dailyCode != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    _dailyCode!,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 5,
                      color: WebsColors.textDark(context),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy code',
                  icon: const Icon(Icons.copy,
                      color: WebsColors.primaryGreen),
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: _dailyCode!),
                    );
                    if (!mounted) return;
                    _showMessage('Location code copied.');
                  },
                ),
              ],
            )
          else
            Text(
              'Your daily location code could not be loaded.',
              style: TextStyle(color: WebsColors.textLight(context)),
            ),
          if (_dailyCodeExpiresAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _formatExpiry(_dailyCodeExpiresAt),
                style: TextStyle(
                  color: WebsColors.textLight(context),
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            'This code changes automatically every 24 hours.',
            style: TextStyle(
              color: WebsColors.textLight(context),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Request another person\'s location',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: WebsColors.textDark(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter their 6-digit Webs location code.',
            style: TextStyle(color: WebsColors.textLight(context)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: '6-digit code',
              labelStyle:
                  TextStyle(color: WebsColors.textLight(context)),
              filled: true,
              fillColor: WebsColors.softGreen(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: WebsColors.primaryGreen,
                  width: 2,
                ),
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  _requesting ? null : _requestOtherPersonLocation,
              icon: _requesting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.location_searching),
              label: const Text('Request location'),
              style: FilledButton.styleFrom(
                backgroundColor: WebsColors.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedLocationCard() {
    final request = _activeRequest;
    if (request == null) return const SizedBox.shrink();

    if (!request.isAccepted) {
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.name}\'s location',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: WebsColors.textDark(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              request.isPending
                  ? 'Waiting for ${widget.name} to accept your request...'
                  : 'Location request is not active.',
              style: TextStyle(color: WebsColors.textLight(context)),
            ),
          ],
        ),
      );
    }

    final staleness = _otherStaleness;
    final isStale = staleness != null && staleness.inMinutes >= 5;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.name}\'s location',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: WebsColors.textDark(context),
                  ),
                ),
              ),
              if (_otherLocation != null) _buildFreshnessBadge(),
            ],
          ),
          const SizedBox(height: 10),

          if (_otherLocation == null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: WebsColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Waiting for ${widget.name}\'s phone to '
                        'upload its location...',
                        style: TextStyle(
                          color: WebsColors.textLight(context),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'This can take a few moments. It updates '
                  'automatically every 8 seconds.',
                  style: TextStyle(
                    color: WebsColors.textLight(context),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _refreshOtherLocation,
                    icon: const Icon(
                      Icons.refresh,
                      color: WebsColors.primaryGreen,
                    ),
                    label: const Text(
                      'Refresh now',
                      style: TextStyle(color: WebsColors.primaryGreen),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: WebsColors.primaryGreen,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else ...[
            if (isStale) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.cloud_off,
                      size: 18,
                      color: Colors.orange.shade800,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This is the last known location. '
                        '${widget.name}\'s phone may be offline or '
                        'the app may be closed.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            Text(
              'Latitude: '
              '${_otherLocation!.latitude.toStringAsFixed(6)}',
              style: TextStyle(color: WebsColors.textDark(context)),
            ),
            Text(
              'Longitude: '
              '${_otherLocation!.longitude.toStringAsFixed(6)}',
              style: TextStyle(color: WebsColors.textDark(context)),
            ),
            if (_otherAccuracy != null)
              Text(
                'Accuracy: ${_otherAccuracy!.toStringAsFixed(1)} m',
                style: TextStyle(color: WebsColors.textDark(context)),
              ),
            if (_otherLocationUpdatedAt != null)
              Text(
                'Updated: '
                '${_otherLocationUpdatedAt!.hour.toString().padLeft(2, '0')}:'
                '${_otherLocationUpdatedAt!.minute.toString().padLeft(2, '0')}',
                style: TextStyle(color: WebsColors.textDark(context)),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _refreshOtherLocation,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    style: FilledButton.styleFrom(
                      backgroundColor: WebsColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _moveToOtherLocation,
                    icon: const Icon(
                      Icons.person_pin_circle,
                      color: WebsColors.primaryGreen,
                    ),
                    label: const Text(
                      'Show',
                      style: TextStyle(color: WebsColors.primaryGreen),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: WebsColors.primaryGreen,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (_routeLoading)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(
                color: WebsColors.primaryGreen,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCustomRouteCard() {
    final hasActiveRoute =
        _customRoute != null && _customRouteRemainingPoints.length >= 2;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Custom Route',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
              color: WebsColors.textDark(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Draw a route manually on the map '
            'when the normal map route does not show '
            'the path you want the other person to follow.',
            style: TextStyle(color: WebsColors.textLight(context)),
          ),
          const SizedBox(height: 12),
          if (hasActiveRoute) ...[
            Row(
              children: [
                const Icon(
                  Icons.route,
                  size: 22,
                  color: WebsColors.primaryGreen,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Route shared with ${widget.name}.',
                    style: TextStyle(
                      color: WebsColors.textDark(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Total distance: '
              '${_formatDistance(_customRoute!.totalDistanceMeters)}',
              style: TextStyle(color: WebsColors.textDark(context)),
            ),
            const SizedBox(height: 4),
            Text(
              'Remaining: '
              '${_formatDistance(_customRouteRemainingDistance ?? 0)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _updateCustomRouteProgress(_currentLocation),
                    icon: const Icon(
                      Icons.refresh,
                      color: WebsColors.primaryGreen,
                    ),
                    label: const Text(
                      'Refresh',
                      style: TextStyle(
                        color: WebsColors.primaryGreen,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: WebsColors.primaryGreen,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _cancelCustomRouteLocally,
                    icon: const Icon(
                      Icons.clear,
                      color: WebsColors.primaryGreen,
                    ),
                    label: const Text(
                      'Hide',
                      style: TextStyle(
                        color: WebsColors.primaryGreen,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: WebsColors.primaryGreen,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Divider(height: 24, color: WebsColors.border(context)),
          ],
          if (_customRouteMode) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: WebsColors.softGreen(context),
              ),
              child: Text(
                'Custom route mode is ON.\n'
                'Tap the map to add points.\n'
                'Points added: ${_routePoints.length}',
                style: TextStyle(color: WebsColors.textDark(context)),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _routePoints.isEmpty
                        ? null
                        : _undoCustomRoutePoint,
                    icon: const Icon(
                      Icons.undo,
                      color: WebsColors.primaryGreen,
                    ),
                    label: const Text(
                      'Undo',
                      style: TextStyle(
                        color: WebsColors.primaryGreen,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: WebsColors.primaryGreen,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _cancelCustomRouteMode,
                    icon: const Icon(
                      Icons.close,
                      color: WebsColors.primaryGreen,
                    ),
                    label: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: WebsColors.primaryGreen,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: WebsColors.primaryGreen,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    _routePoints.length < 2 || _customRouteGenerating
                        ? null
                        : _generateCustomRoute,
                icon: _customRouteGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.route),
                label: Text(
                  _customRouteGenerating
                      ? 'Generating route...'
                      : 'Generate Route',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: WebsColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _startCustomRouteMode,
                icon: const Icon(Icons.edit_road),
                label: const Text('Draw Custom Route'),
                style: FilledButton.styleFrom(
                  backgroundColor: WebsColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==================================================================
  // BUILD
  // ==================================================================

  @override
  Widget build(BuildContext context) {
    const double tickerHeight = 30.0;

    final showOtherTicker =
        _activeRequest != null && _activeRequest!.isAccepted;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
        actions: [
          if (_activeDestination != null)
            IconButton(
              onPressed: _moveToDestination,
              tooltip: 'Destination',
              icon: const Icon(Icons.flag),
            ),
          IconButton(
            onPressed: _moveToCurrentLocation,
            tooltip: 'My location',
            icon: const Icon(Icons.my_location),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLocation ??
                    _cachedLastPosition ??
                    const LatLng(-6.7924, 39.2083),
                initialZoom: 15,
                onTap: (tapPosition, point) {
                  if (_customRouteMode) _addRoutePoint(point);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.webspeople.app',
                ),

                if (_routeGeometry.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routeGeometry,
                        strokeWidth: 5,
                        color: WebsColors.primaryGreen,
                      ),
                    ],
                  ),

                if (_customRouteRemainingPoints.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _customRouteRemainingPoints,
                        strokeWidth: 7,
                        color: WebsColors.accentGreen,
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                    ],
                  ),

                if (_destinationRouteGeometry.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _destinationRouteGeometry,
                        strokeWidth: 6,
                        color: const Color(0xFF1976D2),
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                    ],
                  ),

                MarkerLayer(
                  markers: [
                    if (_currentLocation != null)
                      Marker(
                        point: _currentLocation!,
                        width: 50,
                        height: 50,
                        child: _buildCurrentLocationMarker(),
                      ),
                    if (_otherLocation != null)
                      Marker(
                        point: _otherLocation!,
                        width: 55,
                        height: 55,
                        child: _buildOtherLocationMarker(),
                      ),
                    if (_activeDestination != null)
                      Marker(
                        point: _activeDestination!.position,
                        width: 55,
                        height: 55,
                        child: _buildDestinationMarker(),
                      ),
                    ..._routePoints.map(
                      (point) => Marker(
                        point: point.position,
                        width: 22,
                        height: 22,
                        child: _buildRoutePointMarker(point.order),
                      ),
                    ),
                  ],
                ),

                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),

          if (_error != null)
            Positioned(
              top: showOtherTicker ? tickerHeight + 10 : 10,
              left: 12,
              right: 12,
              child: Material(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            setState(() => _error = null),
                        icon: const Icon(Icons.close, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          Positioned(
            left: 0,
            right: 0,
            top: showOtherTicker ? tickerHeight : 0,
            bottom: tickerHeight,
            child: _buildInfoPanel(),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: tickerHeight,
            child: LocationTicker(
              data: _tickerData,
              pixelsPerSecond: 40,
            ),
          ),

          if (showOtherTicker)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: tickerHeight,
              child: LocationTicker(
                data: _otherTickerData,
                pixelsPerSecond: 40,
              ),
            ),
        ],
      ),
    );
  }
}