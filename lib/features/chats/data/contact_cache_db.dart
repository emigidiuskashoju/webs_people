import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/phone_contact.dart';
import '../services/contact_match_service.dart';

/// Local SQLite cache for phone contacts and their matched
/// Webs users.
///
/// WhatsApp-style loading:
///   - First launch reads contacts from the OS and stores them here.
///   - Every later launch reads from here (instant).
///   - A background refresh updates the cache every 12 hours.
///   - Pull-to-refresh forces an immediate refresh.
///
/// Cleared on logout (see AuthService.logout).
class ContactCacheDb {
  static const String _databaseName = 'webs_contacts_cache.db';
  static const int _databaseVersion = 1;

  static const String _contactsTable = 'cached_contacts';
  static const String _matchesTable = 'cached_matches';
  static const String _metadataTable = 'cache_metadata';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE $_contactsTable (
            phone_number TEXT PRIMARY KEY,
            name TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE $_matchesTable (
            phone_number TEXT PRIMARY KEY,
            user_id INTEGER NOT NULL,
            user_name TEXT NOT NULL,
            profile_photo_url TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE $_metadataTable (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // ============================================================
  // CONTACTS
  // ============================================================

  Future<List<PhoneContact>> readContacts() async {
    final db = await database;
    final rows = await db.query(_contactsTable, orderBy: 'name ASC');

    return rows.map((row) {
      return PhoneContact(
        name: row['name'] as String? ?? '',
        phoneNumber: row['phone_number'] as String? ?? '',
      );
    }).toList();
  }

  Future<void> writeContacts(List<PhoneContact> contacts) async {
    final db = await database;
    final batch = db.batch();

    // Clear + repopulate.
    batch.delete(_contactsTable);

    for (final contact in contacts) {
      batch.insert(
        _contactsTable,
        {
          'phone_number': contact.phoneNumber,
          'name': contact.name,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  // ============================================================
  // MATCHES
  // ============================================================

  Future<Map<String, ContactMatchUser>> readMatches() async {
    final db = await database;
    final rows = await db.query(_matchesTable);

    final result = <String, ContactMatchUser>{};

    for (final row in rows) {
      final phone = row['phone_number'] as String? ?? '';
      if (phone.isEmpty) continue;

      result[phone] = ContactMatchUser(
        id: row['user_id'] as int? ?? 0,
        name: row['user_name'] as String? ?? '',
        phoneNumber: phone,
        profilePhotoUrl: row['profile_photo_url'] as String?,
      );
    }

    return result;
  }

  Future<void> writeMatches(
    Map<String, ContactMatchUser> matches,
  ) async {
    final db = await database;
    final batch = db.batch();

    batch.delete(_matchesTable);

    for (final entry in matches.entries) {
      final user = entry.value;
      batch.insert(
        _matchesTable,
        {
          'phone_number': entry.key,
          'user_id': user.id,
          'user_name': user.name,
          'profile_photo_url': user.profilePhotoUrl,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  // ============================================================
  // METADATA
  // ============================================================

  Future<DateTime?> readLastSyncAt() async {
    final db = await database;
    final rows = await db.query(
      _metadataTable,
      where: 'key = ?',
      whereArgs: ['last_sync_at'],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final raw = rows.first['value'] as String?;
    if (raw == null) return null;

    return DateTime.tryParse(raw);
  }

  Future<void> writeLastSyncAt(DateTime value) async {
    final db = await database;
    await db.insert(
      _metadataTable,
      {
        'key': 'last_sync_at',
        'value': value.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int?> readCurrentUserId() async {
    final db = await database;
    final rows = await db.query(
      _metadataTable,
      where: 'key = ?',
      whereArgs: ['current_user_id'],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final raw = rows.first['value'] as String?;
    if (raw == null) return null;

    return int.tryParse(raw);
  }

  Future<void> writeCurrentUserId(int userId) async {
    final db = await database;
    await db.insert(
      _metadataTable,
      {
        'key': 'current_user_id',
        'value': userId.toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ============================================================
  // CLEAR
  // ============================================================

  Future<void> clear() async {
    final db = await database;
    await db.delete(_contactsTable);
    await db.delete(_matchesTable);
    await db.delete(_metadataTable);
  }
}