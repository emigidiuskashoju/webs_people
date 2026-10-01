import 'dart:io';

import 'package:path_provider/path_provider.dart';

class ProfileStorage {
  static const String _profilePhotoFileName =
      'webs_profile_photo.jpg';

  Future<Directory> _profileDirectory() async {
    final directory = await getApplicationDocumentsDirectory();

    final profileDirectory = Directory(
      '${directory.path}/webs_profile',
    );

    if (!await profileDirectory.exists()) {
      await profileDirectory.create(
        recursive: true,
      );
    }

    return profileDirectory;
  }

  Future<File> _profilePhotoFile() async {
    final directory = await _profileDirectory();

    return File(
      '${directory.path}/$_profilePhotoFileName',
    );
  }

  Future<String?> getProfilePhotoPath() async {
    final file = await _profilePhotoFile();

    if (!await file.exists()) {
      return null;
    }

    return file.path;
  }

  Future<String> saveProfilePhoto(
    File sourceFile,
  ) async {
    final destination = await _profilePhotoFile();

    await sourceFile.copy(
      destination.path,
    );

    return destination.path;
  }

  Future<void> deleteProfilePhoto() async {
    final file = await _profilePhotoFile();

    if (await file.exists()) {
      await file.delete();
    }
  }
}