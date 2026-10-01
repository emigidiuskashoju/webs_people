class Connection {
  final int id;
  final String name;

  const Connection({
    required this.id,
    required this.name,
  });

  factory Connection.fromJson(
    Map<String, dynamic> json,
  ) {
    return Connection(
      id: json['id'] as int,
      name: json['name']?.toString() ?? '',
    );
  }
}