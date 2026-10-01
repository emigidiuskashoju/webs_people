class LocationRequest {
  final int id;
  final int requesterId;
  final int ownerId;

  final String? requesterName;
  final String? ownerName;

  final LocationRequestStatus status;

  final DateTime? createdAt;
  final DateTime? expiresAt;

  final List<SharedLocation> sharedLocations;

  const LocationRequest({
    required this.id,
    required this.requesterId,
    required this.ownerId,
    required this.requesterName,
    required this.ownerName,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    required this.sharedLocations,
  });

  bool get isAccepted =>
      status == LocationRequestStatus.accepted;

  bool get isPending =>
      status == LocationRequestStatus.pending;

  /// True when the *other* person has posted coordinates.
  ///
  /// Pass the current user's id so the model knows which
  /// shared row counts as "the other person".
  bool hasOtherLocation(int currentUserId) =>
      otherLocation(currentUserId) != null;

  /// The other person's shared location, or `null` if they
  /// have not posted one yet.
  SharedLocation? otherLocation(int currentUserId) {
    for (final row in sharedLocations) {
      if (row.userId != currentUserId) {
        return row;
      }
    }

    return null;
  }

  /// The current user's own shared location on this request,
  /// or `null` if they have not posted one yet.
  SharedLocation? myLocation(int currentUserId) {
    for (final row in sharedLocations) {
      if (row.userId == currentUserId) {
        return row;
      }
    }

    return null;
  }

  factory LocationRequest.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawShared = json['shared_locations'];

    final shared = <SharedLocation>[];

    if (rawShared is List) {
      for (final item in rawShared) {
        if (item is Map) {
          shared.add(
            SharedLocation.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }

    return LocationRequest(
      id: _toInt(json['id']) ?? 0,
      requesterId: _toInt(json['requester_id']) ?? 0,
      ownerId: _toInt(json['owner_id']) ?? 0,
      requesterName: json['requester_name']?.toString(),
      ownerName: json['owner_name']?.toString(),
      status: LocationRequestStatus.fromString(
        json['status']?.toString(),
      ),
      createdAt: _toDateTime(json['created_at']),
      expiresAt: _toDateTime(json['expires_at']),
      sharedLocations: shared,
    );
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

class SharedLocation {
  final int userId;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime? updatedAt;

  const SharedLocation({
    required this.userId,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.updatedAt,
  });

  factory SharedLocation.fromJson(
    Map<String, dynamic> json,
  ) {
    return SharedLocation(
      userId: _toInt(json['user_id']) ?? 0,
      latitude: _toDouble(json['latitude']) ?? 0,
      longitude: _toDouble(json['longitude']) ?? 0,
      accuracy: _toDouble(json['accuracy']),
      updatedAt: _toDateTime(json['updated_at']),
    );
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

enum LocationRequestStatus {
  pending,
  accepted,
  denied,
  expired;

  static LocationRequestStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'accepted':
        return LocationRequestStatus.accepted;
      case 'denied':
        return LocationRequestStatus.denied;
      case 'expired':
        return LocationRequestStatus.expired;
      case 'pending':
      default:
        return LocationRequestStatus.pending;
    }
  }
}