class ContactMatch {
  final int id;
  final String name;
  final String phoneNumber;

  const ContactMatch({
    required this.id,
    required this.name,
    required this.phoneNumber,
  });

  factory ContactMatch.fromJson(
    Map<String, dynamic> json,
  ) {
    return ContactMatch(
      id: int.parse(
        json['id'].toString(),
      ),
      name:
          json['name']?.toString() ?? '',
      phoneNumber:
          json['phone_number']
              ?.toString() ??
          '',
    );
  }
}