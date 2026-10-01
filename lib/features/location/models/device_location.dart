class DeviceLocation {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double? altitude;
  final double? speed;
  final double? heading;
  final DateTime timestamp;

  const DeviceLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.altitude,
    this.speed,
    this.heading,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'altitude': altitude,
      'speed': speed,
      'heading': heading,
      'recorded_at': timestamp.toUtc().toIso8601String(),
    };
  }

  factory DeviceLocation.fromJson(Map<String, dynamic> json) {
    return DeviceLocation(
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      accuracy: double.parse(json['accuracy'].toString()),
      altitude: json['altitude'] == null
          ? null
          : double.tryParse(json['altitude'].toString()),
      speed: json['speed'] == null
          ? null
          : double.tryParse(json['speed'].toString()),
      heading: json['heading'] == null
          ? null
          : double.tryParse(json['heading'].toString()),
      timestamp: DateTime.parse(json['recorded_at'].toString()),
    );
  }
}
