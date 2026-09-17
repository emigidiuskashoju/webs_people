import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../models/local_profile.dart';

class ProfileRepository {
  final AppDatabase _database;

  ProfileRepository({
    AppDatabase? database,
  }) : _database = database ?? AppDatabase();

  Future<LocalProfile?> getProfile(
    int userId,
  ) async {
    final database = await _database.database;

    final rows = await database.query(
      'local_profile',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return LocalProfile.fromMap(
      rows.first,
    );
  }

  Future<LocalProfile> saveProfile({
    required int userId,
    String? about,
    String? profilePhotoPath,
  }) async {
    final database = await _database.database;

    final now = DateTime.now();

    final existing = await getProfile(userId);

    final profile = LocalProfile(
      id: userId,
      about: about,
      profilePhotoPath: profilePhotoPath,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    await database.insert(
      'local_profile',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return profile;
  }

  Future<void> deleteProfile(
    int userId,
  ) async {
    final database = await _database.database;

    await database.delete(
      'local_profile',
      where: 'id = ?',
      whereArgs: [userId],
    );
  }
}