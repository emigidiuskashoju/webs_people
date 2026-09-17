class LocalProfile {
  final int id;
  final String? about;
  final String? profilePhotoPath;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LocalProfile({
    required this.id,
    this.about,
    this.profilePhotoPath,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LocalProfile.fromMap(
    Map<String, dynamic> map,
  ) {
    return LocalProfile(
      id: map['id'] as int,
      about:
          map['about']?.toString(),
      profilePhotoPath:
          map['profile_photo_path']
              ?.toString(),
      createdAt:
          DateTime.parse(
        map['created_at']
            .toString(),
      ),
      updatedAt:
          DateTime.parse(
        map['updated_at']
            .toString(),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'about': about,
      'profile_photo_path':
          profilePhotoPath,
      'created_at':
          createdAt.toIso8601String(),
      'updated_at':
          updatedAt.toIso8601String(),
    };
  }
}