import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/chat_message.dart';

/// Summary info about a conversation, used to render the chats
/// list without loading every message.
///
/// `lastMessageText` is the text of the most recent message in
/// the conversation (from either side). `lastMessageAt` is its
/// timestamp. `lastMessageIsMine` tells the UI whether to prefix
/// the preview with "You:".
class ConversationSummary {
  final String lastMessageText;
  final DateTime lastMessageAt;
  final bool lastMessageIsMine;
  final int unreadCount;

  const ConversationSummary({
    required this.lastMessageText,
    required this.lastMessageAt,
    required this.lastMessageIsMine,
    required this.unreadCount,
  });
}

class ChatDatabase {
  static const String _databaseName = 'webs_chat.db';

  static const int _databaseVersion = 2;

  static const String _messagesTable = 'messages';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _openDatabase();

    return _database!;
  }

  Future<Database> _openDatabase() async {
    final databasesPath = await getDatabasesPath();

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
          // Version 2 introduced no new columns.
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
      conflictAlgorithm: ConflictAlgorithm.replace,
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
      whereArgs: [message.localId],
    );
  }

  // ===================================================================
  // GET CONVERSATION
  // ===================================================================
  //
  // Two accounts on one device can create two rows for the same
  // physical message. Only the row belonging to the current
  // account is returned.
  //
  // ===================================================================

  Future<List<ChatMessage>> getConversation(
    String conversationId, {
    required int currentUserId,
  }) async {
    final db = await database;

    final rows = await db.query(
      _messagesTable,
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at ASC',
    );

    final result = <ChatMessage>[];

    for (final row in rows) {
      final message = _fromMap(row);

      final isReceivedCopy = message.localId.startsWith('recv_');

      final belongsToCurrentUser = isReceivedCopy
          ? message.recipientId == currentUserId
          : message.senderId == currentUserId;

      if (!belongsToCurrentUser) {
        continue;
      }

      result.add(
        message.copyWith(
          isMine: message.senderId == currentUserId,
        ),
      );
    }

    return result;
  }

  Future<ChatMessage?> findByLocalId(
    String localId,
  ) async {
    final db = await database;

    final rows = await db.query(
      _messagesTable,
      where: 'local_id = ?',
      whereArgs: [localId],
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
      whereArgs: [serverId],
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
      whereArgs: [MessageStatus.pending.name],
      orderBy: 'created_at ASC',
    );

    return rows.map(_fromMap).toList();
  }

  Future<void> deleteMessage(String localId) async {
  final db = await database;
  await db.delete(
    'messages',           // ← your table name (check yours)
    where: 'local_id = ?',
    whereArgs: [localId],
  );
}

  // ===================================================================
  // CONVERSATION SUMMARY
  // ===================================================================
  //
  // Returns, for every conversation the current user is part of:
  //
  //   - the text of the last message (from either side)
  //   - the timestamp of the last message
  //   - whether the last message was sent by the current user
  //   - the count of unread messages (delivered, not yet read)
  //
  // Only rows belonging to the current account are considered —
  // the same `recv_` rule from getConversation applies.
  //
  // ===================================================================

  Future<Map<String, ConversationSummary>> getConversationSummaries({
    required int currentUserId,
  }) async {
    final db = await database;

    final rows = await db.query(
      _messagesTable,
      orderBy: 'created_at ASC',
    );

    // Map: conversationId → best summary so far.
    final summaries = <String, ConversationSummary>{};

    for (final row in rows) {
      final message = _fromMap(row);

      final isReceivedCopy = message.localId.startsWith('recv_');

      final belongsToCurrentUser = isReceivedCopy
          ? message.recipientId == currentUserId
          : message.senderId == currentUserId;

      if (!belongsToCurrentUser) {
        continue;
      }

      final conversationId = message.conversationId;

      final isMine = message.senderId == currentUserId;

      // Unread counts only delivered messages addressed to me.
      final isUnread =
          !isMine && message.status == MessageStatus.delivered;

      final existing = summaries[conversationId];

      final newUnreadCount =
          (existing?.unreadCount ?? 0) + (isUnread ? 1 : 0);

      // Replace the "last message" only if this row is newer.
      final isNewer = existing == null ||
          message.createdAt.isAfter(existing.lastMessageAt);

      summaries[conversationId] = ConversationSummary(
        lastMessageText: isNewer
            ? message.text
            : existing!.lastMessageText,
        lastMessageAt: isNewer
            ? message.createdAt
            : existing!.lastMessageAt,
        lastMessageIsMine: isNewer
            ? isMine
            : existing!.lastMessageIsMine,
        unreadCount: newUnreadCount,
      );
    }

    return summaries;
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
      'local_id': message.localId,
      'server_id': message.serverId,
      'sender_id': message.senderId,
      'recipient_id': message.recipientId,
      'conversation_id': message.conversationId,
      'text': message.text,
      'created_at': message.createdAt.toIso8601String(),
      'status': message.status.name,
      'is_mine': message.isMine ? 1 : 0,
    };
  }

  ChatMessage _fromMap(
    Map<String, dynamic> map,
  ) {
    return ChatMessage(
      localId: map['local_id'] as String,
      serverId: map['server_id'] as int?,
      senderId: map['sender_id'] as int,
      recipientId: map['recipient_id'] as int,
      conversationId: map['conversation_id'] as String,
      text: map['text'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      status: MessageStatus.values.firstWhere(
        (value) => value.name == map['status'],
        orElse: () => MessageStatus.failed,
      ),
      isMine: (map['is_mine'] as int) == 1,
    );
  }
}