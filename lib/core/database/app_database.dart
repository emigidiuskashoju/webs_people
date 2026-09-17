import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const String _databaseName =
      'webs_people.db';

  static const int _databaseVersion = 3;

  final Database? _providedDatabase;

  Database? _database;

  AppDatabase({
    Database? database,
  }) : _providedDatabase = database;

  Future<Database> get database async {
    if (_providedDatabase != null) {
      return _providedDatabase!;
    }

    if (_database != null) {
      return _database!;
    }

    _database = await _openDatabase();

    return _database!;
  }

  Future<Database> _openDatabase() async {
    final databasesPath =
        await getDatabasesPath();

    final path = join(
      databasesPath,
      _databaseName,
    );

    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  static Future<void> createTables(
    Database database,
  ) async {
    // ============================================================
    // PHASE 2
    // Local user profile
    // ============================================================

    await database.execute('''
      CREATE TABLE local_profile (
        id INTEGER PRIMARY KEY,
        about TEXT,
        profile_photo_path TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // ============================================================
    // PHASE 6
    // Local conversations
    // ============================================================

    await database.execute('''
      CREATE TABLE local_conversations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        other_user_id INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // ============================================================
    // PHASE 6
    // Local messages
    // ============================================================

    await database.execute('''
      CREATE TABLE local_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        conversation_id INTEGER NOT NULL,
        sender_id INTEGER NOT NULL,
        receiver_id INTEGER NOT NULL,
        client_message_id TEXT NOT NULL UNIQUE,
        body TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        sent_at TEXT,
        delivered_at TEXT,
        read_at TEXT
      )
    ''');

    // ============================================================
    // PHASE 8
    // Saved routes
    // ============================================================

    await database.execute('''
      CREATE TABLE saved_routes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        start_latitude REAL NOT NULL,
        start_longitude REAL NOT NULL,
        destination_latitude REAL NOT NULL,
        destination_longitude REAL NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // ============================================================
    // PHASE 8
    // Route points
    // ============================================================

    await database.execute('''
      CREATE TABLE route_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        route_id INTEGER NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        sequence INTEGER NOT NULL
      )
    ''');

    // ============================================================
    // INDEXES
    // ============================================================

    await database.execute('''
      CREATE INDEX idx_local_messages_conversation
      ON local_messages(conversation_id)
    ''');

    await database.execute('''
      CREATE INDEX idx_local_messages_status
      ON local_messages(status)
    ''');

    await database.execute('''
      CREATE INDEX idx_local_messages_created_at
      ON local_messages(created_at)
    ''');

    await database.execute('''
      CREATE INDEX idx_route_points_route
      ON route_points(route_id)
    ''');

    await database.execute('''
      CREATE INDEX idx_route_points_sequence
      ON route_points(route_id, sequence)
    ''');
  }

  // ==============================================================
  // CREATE DATABASE
  // ==============================================================

  static Future<void> _createDatabase(
    Database database,
    int version,
  ) async {
    await createTables(database);
  }

  // ==============================================================
  // DATABASE UPGRADES
  // ==============================================================

  static Future<void> _upgradeDatabase(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    // ============================================================
    // VERSION 1 → VERSION 2
    // Add chat tables
    // ============================================================

    if (oldVersion < 2) {
      await database.execute('''
        CREATE TABLE local_conversations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          other_user_id INTEGER NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      await database.execute('''
        CREATE TABLE local_messages (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          conversation_id INTEGER NOT NULL,
          sender_id INTEGER NOT NULL,
          receiver_id INTEGER NOT NULL,
          client_message_id TEXT NOT NULL UNIQUE,
          body TEXT NOT NULL,
          status TEXT NOT NULL,
          created_at TEXT NOT NULL,
          sent_at TEXT,
          delivered_at TEXT,
          read_at TEXT
        )
      ''');

      await database.execute('''
        CREATE INDEX idx_local_messages_conversation
        ON local_messages(conversation_id)
      ''');

      await database.execute('''
        CREATE INDEX idx_local_messages_status
        ON local_messages(status)
      ''');

      await database.execute('''
        CREATE INDEX idx_local_messages_created_at
        ON local_messages(created_at)
      ''');
    }

    // ============================================================
    // VERSION 2 → VERSION 3
    // Add route tables
    // ============================================================

    if (oldVersion < 3) {
      await database.execute('''
        CREATE TABLE saved_routes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          start_latitude REAL NOT NULL,
          start_longitude REAL NOT NULL,
          destination_latitude REAL NOT NULL,
          destination_longitude REAL NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');

      await database.execute('''
        CREATE TABLE route_points (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          route_id INTEGER NOT NULL,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          sequence INTEGER NOT NULL
        )
      ''');

      await database.execute('''
        CREATE INDEX idx_route_points_route
        ON route_points(route_id)
      ''');

      await database.execute('''
        CREATE INDEX idx_route_points_sequence
        ON route_points(route_id, sequence)
      ''');
    }
  }
}