class RecoveryDevice {
  final int id;
  final String name;

  final bool isLost;
  final bool isActive;

  final DateTime? lastSeenAt;

  final double? latitude;
  final double? longitude;
  final double? accuracy;

  final DateTime? locationRecordedAt;

  const RecoveryDevice({
    required this.id,
    required this.name,
    required this.isLost,
    required this.isActive,
    required this.lastSeenAt,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.locationRecordedAt,
  });

  // ============================================================
  // LOCATION
  // ============================================================

  bool get hasLocation {
    return latitude != null &&
        longitude != null;
  }

  // ============================================================
  // ONLINE STATUS
  // ============================================================

  bool get isOnline {
    final lastSeen = lastSeenAt;

    if (lastSeen == null) {
      return false;
    }

    final age = DateTime.now().toUtc().difference(
          lastSeen.toUtc(),
        );

    return age.inSeconds <= 120;
  }

  // ============================================================
  // RECENTLY SEEN
  // ============================================================

  bool get wasRecentlySeen {
    final lastSeen = lastSeenAt;

    if (lastSeen == null) {
      return false;
    }

    final age = DateTime.now().toUtc().difference(
          lastSeen.toUtc(),
        );

    return age.inMinutes <= 10;
  }

  // ============================================================
  // STATUS TEXT
  // ============================================================

  String get connectionStatus {
    if (isOnline) {
      return 'Online';
    }

    if (wasRecentlySeen) {
      return 'Recently seen';
    }

    return 'Offline';
  }

  // ============================================================
  // STATUS AGE
  // ============================================================

  String get lastSeenText {
    final lastSeen = lastSeenAt;

    if (lastSeen == null) {
      return 'Never';
    }

    final local = lastSeen.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}:'
        '${local.second.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // JSON
  // ============================================================

  factory RecoveryDevice.fromJson(
    Map<String, dynamic> json,
  ) {
    final latestLocation =
        json['latest_location'] ??
        json['latestLocation'];

    Map<String, dynamic>? location;

    if (latestLocation is Map) {
      location = Map<String, dynamic>.from(
        latestLocation,
      );
    }

    final rawId = json['id'];

    final id = rawId is int
        ? rawId
        : int.tryParse(
              rawId?.toString() ?? '',
            ) ??
            0;

    return RecoveryDevice(
      id: id,

      name: _safeDeviceName(
        json['name'],
      ),

      isLost:
          json['is_lost'] == true,

      isActive:
          json['is_active'] == true,

      lastSeenAt:
          _parseDateTime(
        json['last_seen_at'],
      ),

      latitude:
          _parseDouble(
        location?['latitude'],
      ),

      longitude:
          _parseDouble(
        location?['longitude'],
      ),

      accuracy:
          _parseDouble(
        location?['accuracy'],
      ),

      locationRecordedAt:
          _parseDateTime(
        location?['recorded_at'],
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  static double? _parseDouble(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }

  static DateTime? _parseDateTime(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(
      value.toString(),
    );
  }

  static String _safeDeviceName(
    dynamic value,
  ) {
    final name = value?.toString().trim();

    if (name == null || name.isEmpty) {
      return 'Webs Device';
    }

    return name;
  }
}