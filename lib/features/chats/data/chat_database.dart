import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/chat_message.dart';

class ChatDatabase {
  static const String _databaseName =
      'webs_people_chat.db';

  static const int _databaseVersion = 2;

  static const String _messagesTable =
      'messages';

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
        await _createMessagesTable(db);
      },

      onUpgrade: (
        Database db,
        int oldVersion,
        int newVersion,
      ) async {
        if (oldVersion < 2) {
          /*
           * Version 2 does not require a new column.
           *
           * Message read state is stored in the
           * existing status column.
           *
           * The database version is increased so
           * future migrations have a clean starting point.
           */
        }
      },
    );
  }

  Future<void> _createMessagesTable(
    Database db,
  ) async {
    await db.execute('''
      CREATE TABLE $_messagesTable (
        local_id TEXT PRIMARY KEY,
        server_id INTEGER,
        sender_id INTEGER NOT NULL,
        recipient_id INTEGER NOT NULL,
        conversation_id TEXT NOT NULL,
        text TEXT NOT NULL,
        created_at TEXT NOT NULL,
        status TEXT NOT NULL,
        is_mine INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_messages_conversation
      ON $_messagesTable(conversation_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_messages_server
      ON $_messagesTable(server_id)
    ''');
  }

  Future<void> insertMessage(
    ChatMessage message,
  ) async {
    final db = await database;

    await db.insert(
      _messagesTable,
      _toMap(message),
      conflictAlgorithm:
          ConflictAlgorithm.replace,
    );
  }

  Future<void> updateMessage(
    ChatMessage message,
  ) async {
    final db = await database;

    await db.update(
      _messagesTable,
      _toMap(message),
      where: 'local_id = ?',
      whereArgs: [
        message.localId,
      ],
    );
  }

  Future<List<ChatMessage>> getConversation(
    String conversationId, {
    required int currentUserId,
  }) async {
    final db = await database;

    final rows = await db.query(
      _messagesTable,
      where: 'conversation_id = ?',
      whereArgs: [
        conversationId,
      ],
      orderBy: 'created_at ASC',
    );

    return rows.map((row) {
      final message = _fromMap(row);

      /*
       * IMPORTANT:
       *
       * Do not trust the stored is_mine value.
       *
       * The same phone can contain multiple Webs
       * People accounts.
       *
       * The sender ID determines whether the
       * message belongs on the right side for
       * the currently active account.
       */
      return message.copyWith(
        isMine:
            message.senderId == currentUserId,
      );
    }).toList();
  }

  Future<ChatMessage?> findByLocalId(
    String localId,
  ) async {
    final db = await database;

    final rows = await db.query(
      _messagesTable,
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

  Future<ChatMessage?> findByServerId(
    int serverId,
  ) async {
    final db = await database;

    final rows = await db.query(
      _messagesTable,
      where: 'server_id = ?',
      whereArgs: [
        serverId,
      ],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return _fromMap(rows.first);
  }

  Future<List<ChatMessage>> getPendingMessages() async {
    final db = await database;

    final rows = await db.query(
      _messagesTable,
      where: 'status = ?',
      whereArgs: [
        MessageStatus.pending.name,
      ],
      orderBy: 'created_at ASC',
    );

    return rows
        .map(_fromMap)
        .toList();
  }

  Future<void> close() async {
    final db = _database;

    if (db != null) {
      await db.close();

      _database = null;
    }
  }

  Map<String, dynamic> _toMap(
    ChatMessage message,
  ) {
    return {
      'local_id':
          message.localId,

      'server_id':
          message.serverId,

      'sender_id':
          message.senderId,

      'recipient_id':
          message.recipientId,

      'conversation_id':
          message.conversationId,

      'text':
          message.text,

      'created_at':
          message.createdAt
              .toIso8601String(),

      'status':
          message.status.name,

      /*
       * Kept for database compatibility.
       *
       * It is no longer trusted when displaying
       * a conversation.
       */
      'is_mine':
          message.isMine ? 1 : 0,
    };
  }

  ChatMessage _fromMap(
    Map<String, dynamic> map,
  ) {
    return ChatMessage(
      localId:
          map['local_id'] as String,

      serverId:
          map['server_id'] as int?,

      senderId:
          map['sender_id'] as int,

      recipientId:
          map['recipient_id'] as int,

      conversationId:
          map['conversation_id'] as String,

      text:
          map['text'] as String,

      createdAt:
          DateTime.parse(
        map['created_at'] as String,
      ),

      status:
          MessageStatus.values.firstWhere(
        (value) =>
            value.name ==
            map['status'],
        orElse: () =>
            MessageStatus.failed,
      ),

      isMine:
          (map['is_mine'] as int) == 1,
    );
  }
}