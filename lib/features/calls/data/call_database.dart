import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/call_record.dart';

class CallDatabase {
  static const String _databaseName =
      'webs_calls.db';

  /*
   * Version 1 contains the complete initial
   * calls table.
   *
   * Future schema changes must increase this
   * number and be handled in onUpgrade().
   */
  static const int _databaseVersion = 1;

  static const String _callsTable = 'calls';

  Database? _database;

  Future<Database> get database async {
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
      onCreate: (
        Database db,
        int version,
      ) async {
        await _createVersion1(db);
      },
      onUpgrade: (
        Database db,
        int oldVersion,
        int newVersion,
      ) async {
        await _upgradeDatabase(
          db,
          oldVersion,
          newVersion,
        );
      },
    );
  }

  Future<void> _createVersion1(
    Database db,
  ) async {
    await db.execute('''
      CREATE TABLE $_callsTable (
        local_id TEXT PRIMARY KEY,
        owner_user_id INTEGER NOT NULL,
        call_id TEXT NOT NULL,
        remote_user_id INTEGER NOT NULL,
        remote_name TEXT NOT NULL,
        remote_phone_number TEXT NOT NULL,
        type TEXT NOT NULL,
        direction TEXT NOT NULL,
        status TEXT NOT NULL,
        started_at TEXT NOT NULL,
        answered_at TEXT,
        ended_at TEXT,
        duration_seconds INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_calls_owner
      ON $_callsTable(owner_user_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_calls_started
      ON $_callsTable(started_at)
    ''');

    await db.execute('''
      CREATE INDEX idx_calls_owner_started
      ON $_callsTable(
        owner_user_id,
        started_at
      )
    ''');
  }

  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    /*
     * IMPORTANT:
     *
     * Never use DROP TABLE here.
     *
     * Existing call history must survive
     * application updates.
     *
     * Future example:
     *
     * if (oldVersion < 2) {
     *   await db.execute(
     *     'ALTER TABLE calls ADD COLUMN ...'
     *   );
     * }
     */

    if (oldVersion < 2) {
      /*
       * Reserved for the first future schema
       * change.
       *
       * Do not add anything here yet.
       */
    }
  }

  Future<void> insertCall(
    CallRecord call,
  ) async {
    final db = await database;

    await db.insert(
      _callsTable,
      _toMap(call),
      conflictAlgorithm:
          ConflictAlgorithm.replace,
    );
  }

  Future<void> updateCall(
    CallRecord call,
  ) async {
    final db = await database;

    await db.update(
      _callsTable,
      _toMap(call),
      where: 'local_id = ?',
      whereArgs: [
        call.localId,
      ],
    );
  }

  Future<CallRecord?> findByLocalId(
    String localId,
  ) async {
    final db = await database;

    final rows = await db.query(
      _callsTable,
      where: 'local_id = ?',
      whereArgs: [
        localId,
      ],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return _fromMap(rows.first);
  }

  Future<CallRecord?> findByCallIdForOwner(
    String callId,
    int ownerUserId,
  ) async {
    final db = await database;

    final rows = await db.query(
      _callsTable,
      where:
          'call_id = ? AND owner_user_id = ?',
      whereArgs: [
        callId,
        ownerUserId,
      ],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return _fromMap(rows.first);
  }

  Future<List<CallRecord>> getCallsForOwner(
    int ownerUserId,
  ) async {
    final db = await database;

    final rows = await db.query(
      _callsTable,
      where: 'owner_user_id = ?',
      whereArgs: [
        ownerUserId,
      ],
      orderBy: 'started_at DESC',
    );

    return rows
        .map(_fromMap)
        .toList();
  }

  Future<void> deleteCallsForOwner(
    int ownerUserId,
  ) async {
    final db = await database;

    await db.delete(
      _callsTable,
      where: 'owner_user_id = ?',
      whereArgs: [
        ownerUserId,
      ],
    );
  }

  Future<void> close() async {
    final db = _database;

    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  Map<String, dynamic> _toMap(
    CallRecord call,
  ) {
    return {
      'local_id':
          call.localId,

      'owner_user_id':
          call.ownerUserId,

      'call_id':
          call.callId,

      'remote_user_id':
          call.remoteUserId,

      'remote_name':
          call.remoteName,

      'remote_phone_number':
          call.remotePhoneNumber,

      'type':
          call.type.name,

      'direction':
          call.direction.name,

      'status':
          call.status.name,

      'started_at':
          call.startedAt.toIso8601String(),

      'answered_at':
          call.answeredAt
              ?.toIso8601String(),

      'ended_at':
          call.endedAt
              ?.toIso8601String(),

      'duration_seconds':
          call.durationSeconds,
    };
  }

  CallRecord _fromMap(
    Map<String, dynamic> map,
  ) {
    return CallRecord(
      localId:
          map['local_id'] as String,

      ownerUserId:
          map['owner_user_id'] as int,

      callId:
          map['call_id'] as String,

      remoteUserId:
          map['remote_user_id'] as int,

      remoteName:
          map['remote_name'] as String,

      remotePhoneNumber:
          map['remote_phone_number']
              as String,

      type:
          CallType.values.firstWhere(
        (value) =>
            value.name ==
            map['type'],
        orElse: () =>
            CallType.audio,
      ),

      direction:
          CallDirection.values.firstWhere(
        (value) =>
            value.name ==
            map['direction'],
        orElse: () =>
            CallDirection.outgoing,
      ),

      status:
          CallStatus.values.firstWhere(
        (value) =>
            value.name ==
            map['status'],
        orElse: () =>
            CallStatus.failed,
      ),

      startedAt:
          DateTime.parse(
        map['started_at'] as String,
      ),

      answeredAt:
          map['answered_at'] == null
              ? null
              : DateTime.parse(
                  map['answered_at']
                      as String,
                ),

      endedAt:
          map['ended_at'] == null
              ? null
              : DateTime.parse(
                  map['ended_at']
                      as String,
                ),

      durationSeconds:
          map['duration_seconds'] as int,
    );
  }
}