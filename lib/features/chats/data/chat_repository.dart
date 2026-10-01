import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/notifications/active_conversation.dart';
import '../../../core/notifications/notification_service.dart';
import '../models/chat_message.dart';
import '../services/message_service.dart';
import 'chat_database.dart';

class ChatRepository {
  final ChatDatabase _database;
  final MessageService _messageService;
  final Uuid _uuid;

  ChatRepository({
    ChatDatabase? database,
    MessageService? messageService,
    Uuid? uuid,
  })  : _database = database ?? ChatDatabase(),
        _messageService = messageService ?? MessageService(),
        _uuid = uuid ?? const Uuid();

  Future<List<ChatMessage>> getConversation(
    String conversationId, {
    required int currentUserId,
  }) {
    return _database.getConversation(
      conversationId,
      currentUserId: currentUserId,
    );
  }

  /// Returns the unread count, last-message preview, and last
  /// message time for every conversation the current user is
  /// part of. Used by ChatsScreen to render the badges and to
  /// sort by recency.
  Future<Map<String, ConversationSummary>> getConversationSummaries({
    required int currentUserId,
  }) {
    return _database.getConversationSummaries(
      currentUserId: currentUserId,
    );
  }

  // ===================================================================
  // SEND
  // ===================================================================

  Future<ChatMessage> createAndSendMessage({
    required int senderId,
    required int recipientId,
    required String conversationId,
    required String text,
  }) async {
    final trimmedText = text.trim();

    if (trimmedText.isEmpty) {
      throw const ApiException('Message cannot be empty.');
    }

    final localId = _uuid.v4();
    final now = DateTime.now();

    var message = ChatMessage(
      localId: localId,
      serverId: null,
      senderId: senderId,
      recipientId: recipientId,
      conversationId: conversationId,
      text: trimmedText,
      createdAt: now,
      status: MessageStatus.pending,
      isMine: true,
    );

    await _database.insertMessage(message);

    debugPrint(
      'SEND: queued localId=$localId '
      'sender=$senderId recipient=$recipientId',
    );

    try {
      final result = await _messageService.sendMessage(
        recipientId: recipientId,
        clientMessageId: localId,
        message: trimmedText,
      );

      message = message.copyWith(
        serverId: result.serverMessageId,
        status: MessageStatus.sent,
      );

      await _database.updateMessage(message);

      debugPrint(
        'SEND: server accepted localId=$localId '
        'serverId=${result.serverMessageId} status=sent',
      );

      return message;
    } catch (e) {
      message = message.copyWith(status: MessageStatus.failed);

      await _database.updateMessage(message);

      debugPrint('SEND: FAILED localId=$localId error=$e');

      return message;
    }
  }

  // ===================================================================
  // RECEIVE
  // ===================================================================

  Future<int> receivePendingMessages({
    required int currentUserId,
  }) async {
    final pending = await _messageService.getPendingMessages();

    debugPrint(
      'RECV: fetched ${pending.length} pending messages '
      'for user $currentUserId',
    );

    var receivedCount = 0;

    for (final serverMessage in pending) {
      debugPrint(
        'RECV: serverId=${serverMessage.serverMessageId} '
        'sender=${serverMessage.senderId} '
        'recipient=${serverMessage.recipientId}',
      );

      if (serverMessage.recipientId != currentUserId) {
        debugPrint(
          'RECV: skipping serverId=${serverMessage.serverMessageId} '
          '(recipient mismatch)',
        );
        continue;
      }

      final recipientLocalId = 'recv_${serverMessage.clientMessageId}';

      final existing =
          await _database.findByLocalId(recipientLocalId);

      if (existing != null) {
        debugPrint(
          'RECV: serverId=${serverMessage.serverMessageId} '
          'already stored for recipient (status=${existing.status.name})',
        );

        if (existing.status != MessageStatus.delivered &&
            existing.status != MessageStatus.read) {
          await _database.updateMessage(
            existing.copyWith(status: MessageStatus.delivered),
          );

          debugPrint(
            'RECV: promoted serverId=${serverMessage.serverMessageId} '
            'to delivered',
          );
        }

        await _messageService.acknowledgeMessage(
          serverMessage.serverMessageId,
        );

        continue;
      }

      final conversationId = _makeConversationId(
        serverMessage.senderId,
        serverMessage.recipientId,
      );

      final localMessage = ChatMessage(
        localId: recipientLocalId,
        serverId: serverMessage.serverMessageId,
        senderId: serverMessage.senderId,
        recipientId: serverMessage.recipientId,
        conversationId: conversationId,
        text: serverMessage.message,
        createdAt: serverMessage.createdAt,
        status: MessageStatus.delivered,
        isMine: serverMessage.senderId == currentUserId,
      );

      await _database.insertMessage(localMessage);

      debugPrint(
        'RECV: stored serverId=${serverMessage.serverMessageId} '
        'as delivered (localId=$recipientLocalId)',
      );

      await _messageService.acknowledgeMessage(
        serverMessage.serverMessageId,
      );

      receivedCount++;

      final isFromMe = serverMessage.senderId == currentUserId;

      if (!isFromMe) {
        final isViewing =
            ActiveConversation.instance.isActive(conversationId);

        if (!isViewing) {
          await NotificationService.instance
              .showMessageNotification(
            senderName: 'New message',
            text: serverMessage.message,
            conversationId: conversationId,
          );

          debugPrint(
            'RECV: fired notification for '
            'serverId=${serverMessage.serverMessageId}',
          );
        } else {
          debugPrint(
            'RECV: suppressed notification for '
            'serverId=${serverMessage.serverMessageId} '
            '(user is viewing $conversationId)',
          );
        }
      }
    }

    debugPrint('RECV: total received=$receivedCount');

    return receivedCount;
  }

  // ===================================================================
  // MARK AS READ
  // ===================================================================

  Future<void> markConversationAsRead({
    required String conversationId,
    required int currentUserId,
  }) async {
    final messages = await _database.getConversation(
      conversationId,
      currentUserId: currentUserId,
    );

    debugPrint(
      'MARK-READ: conversation=$conversationId '
      'messages=${messages.length}',
    );

    for (final message in messages) {
      if (message.isMine) continue;
      if (message.serverId == null) continue;
      if (message.status == MessageStatus.read) continue;
      if (message.status != MessageStatus.delivered) continue;

      try {
        await _messageService.markMessageRead(message.serverId!);

        await _database.updateMessage(
          message.copyWith(status: MessageStatus.read),
        );

        debugPrint(
          'MARK-READ: serverId=${message.serverId} -> read',
        );
      } catch (e) {
        debugPrint(
          'MARK-READ: FAILED for serverId=${message.serverId}: $e',
        );
      }
    }
  }

  // ===================================================================
  // SYNC READ RECEIPTS
  // ===================================================================

  Future<int> syncReadReceipts() async {
    final receipts = await _messageService.getPendingReadReceipts();

    debugPrint('SYNC-RECEIPTS: fetched ${receipts.length} receipts');

    var updatedCount = 0;

    for (final receipt in receipts) {
      final message =
          await _database.findByServerId(receipt.messageId);

      if (message != null && message.status != MessageStatus.read) {
        await _database.updateMessage(
          message.copyWith(status: MessageStatus.read),
        );
        updatedCount++;
      }

      await _messageService.acknowledgeReadReceipt(receipt.id);
    }

    debugPrint('SYNC-RECEIPTS: updated=$updatedCount');

    return updatedCount;
  }

  // ===================================================================
  // RETRY
  // ===================================================================

  Future<void> retryFailedMessage(ChatMessage message) async {
    if (message.status != MessageStatus.failed) return;

    try {
      final result = await _messageService.sendMessage(
        recipientId: message.recipientId,
        clientMessageId: message.localId,
        message: message.text,
      );

      final updated = message.copyWith(
        serverId: result.serverMessageId,
        status: MessageStatus.sent,
        isMine: true,
      );

      await _database.updateMessage(updated);

      debugPrint(
        'RETRY: sent localId=${message.localId} '
        'serverId=${result.serverMessageId}',
      );
    } catch (e) {
      debugPrint('RETRY: FAILED localId=${message.localId}: $e');
    }
  }

  // ===================================================================
  // DELETE
  // ===================================================================
  //
  // Called by ChatScreen when the user long-presses a message and
  // chooses Delete from the actions sheet.
  //
  // The message is removed from the local SQLite database only.
  // The server copy is NOT deleted — other participants still see
  // the message, and the sender's own record is untouched.
  //
  // If you later want "delete for everyone", add a server-side
  // delete endpoint and call it here as well.

  Future<void> deleteMessage(ChatMessage message) async {
    debugPrint('DELETE: localId=${message.localId}');

    await _database.deleteMessage(message.localId);

    debugPrint('DELETE: removed localId=${message.localId}');
  }

  // ===================================================================
  // CONVERSATION ID
  // ===================================================================

  String createConversationId(int userA, int userB) {
    return _makeConversationId(userA, userB);
  }

  String _makeConversationId(int userA, int userB) {
    final ids = [userA, userB]..sort();
    return '${ids[0]}_${ids[1]}';
  }
}