class PeopleLocation {
  final int userId;
  final String userName;
  final String phoneNumber;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime expiresAt;

  const PeopleLocation({
    required this.userId,
    required this.userName,
    required this.phoneNumber,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.expiresAt,
  });

  factory PeopleLocation.fromJson(
    Map<String, dynamic> json,
  ) {
    final user =
        json['user'] is Map<String, dynamic>
            ? json['user']
                as Map<String, dynamic>
            : <String, dynamic>{};

    return PeopleLocation(
      userId: int.parse(
        json['user_id'].toString(),
      ),
      userName:
          user['name']?.toString() ?? '',
      phoneNumber:
          user['phone_number']
                  ?.toString() ??
              '',
      latitude: double.parse(
        json['latitude'].toString(),
      ),
      longitude: double.parse(
        json['longitude'].toString(),
      ),
      accuracy:
          json['accuracy'] == null
              ? null
              : double.parse(
                  json['accuracy'].toString(),
                ),
      expiresAt: DateTime.parse(
        json['expires_at'].toString(),
      ),
    );
  }
}