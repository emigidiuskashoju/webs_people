class SavedRoute {
  final int? id;
  final String name;
  final double startLatitude;
  final double startLongitude;
  final double destinationLatitude;
  final double destinationLongitude;
  final DateTime createdAt;

  const SavedRoute({
    this.id,
    required this.name,
    required this.startLatitude,
    required this.startLongitude,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'start_latitude':
          startLatitude,
      'start_longitude':
          startLongitude,
      'destination_latitude':
          destinationLatitude,
      'destination_longitude':
          destinationLongitude,
      'created_at':
          createdAt.toIso8601String(),
    };
  }

  factory SavedRoute.fromMap(
    Map<String, dynamic> map,
  ) {
    return SavedRoute(
      id: map['id'] == null
          ? null
          : int.parse(
              map['id'].toString(),
            ),
      name:
          map['name'].toString(),
      startLatitude: double.parse(
        map['start_latitude']
            .toString(),
      ),
      startLongitude: double.parse(
        map['start_longitude']
            .toString(),
      ),
      destinationLatitude:
          double.parse(
        map['destination_latitude']
            .toString(),
      ),
      destinationLongitude:
          double.parse(
        map['destination_longitude']
            .toString(),
      ),
      createdAt:
          DateTime.parse(
        map['created_at']
            .toString(),
      ),
    );
  }
}