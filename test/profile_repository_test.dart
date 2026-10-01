import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:webs_people/core/database/app_database.dart';
import 'package:webs_people/features/profile/repositories/profile_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();

    databaseFactory =
        databaseFactoryFfi;
  });

  test(
    'profile can be saved and loaded locally',
    () async {
      final database =
          await databaseFactory.openDatabase(
        inMemoryDatabasePath,
      );

      await AppDatabase.createTables(
        database,
      );

      final repository =
          ProfileRepository(
        database:
            AppDatabase(
          database: database,
        ),
      );

      await repository.saveProfile(
        userId: 1,
        about:
            'I am using Webs.',
      );

      final profile =
          await repository.getProfile(
        1,
      );

      expect(
        profile,
        isNotNull,
      );

      expect(
        profile!.id,
        1,
      );

      expect(
        profile.about,
        'I am using Webs.',
      );

      await database.close();
    },
  );

  test(
    'profile can be deleted locally',
    () async {
      final database =
          await databaseFactory.openDatabase(
        inMemoryDatabasePath,
      );

      await AppDatabase.createTables(
        database,
      );

      final repository =
          ProfileRepository(
        database:
            AppDatabase(
          database: database,
        ),
      );

      await repository.saveProfile(
        userId: 2,
        about: 'Temporary',
      );

      await repository.deleteProfile(
        2,
      );

      final profile =
          await repository.getProfile(
        2,
      );

      expect(
        profile,
        isNull,
      );

      await database.close();
    },
  );
}