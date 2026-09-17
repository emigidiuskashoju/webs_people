import '../models/local_profile.dart';
import '../repositories/profile_repository.dart';

class ProfileService {
  final ProfileRepository _repository;

  ProfileService({
    ProfileRepository? repository,
  }) : _repository =
            repository ??
                ProfileRepository();

  Future<LocalProfile?> getProfile(
    int userId,
  ) {
    return _repository.getProfile(
      userId,
    );
  }

  Future<LocalProfile> saveProfile({
    required int userId,
    String? about,
    String? profilePhotoPath,
  }) {
    return _repository.saveProfile(
      userId: userId,
      about: about,
      profilePhotoPath:
          profilePhotoPath,
    );
  }

  Future<void> deleteProfile(
    int userId,
  ) {
    return _repository.deleteProfile(
      userId,
    );
  }
}