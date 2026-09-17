class UserModel {
  final int id;
  final String name;
  final String phoneNumber;
  final DateTime? phoneVerifiedAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.phoneVerifiedAt,
  });

  factory UserModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return UserModel(
      id: int.parse(
        json['id'].toString(),
      ),
      name: json['name']?.toString() ?? '',
      phoneNumber:
          json['phone_number']?.toString() ?? '',
      phoneVerifiedAt:
          json['phone_verified_at'] == null
              ? null
              : DateTime.tryParse(
                  json['phone_verified_at'].toString(),
                ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone_number': phoneNumber,
      'phone_verified_at':
          phoneVerifiedAt?.toIso8601String(),
    };
  }
}