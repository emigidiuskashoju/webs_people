import 'package:uuid/uuid.dart';

import '../../../core/errors/api_exception.dart';
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
  })  : _database =
            database ?? ChatDatabase(),
        _messageService =
            messageService ??
                MessageService(),
        _uuid =
            uuid ?? const Uuid();

  Future<List<ChatMessage>> getConversation(
    String conversationId, {
    required int currentUserId,
  }) {
    return _database.getConversation(
      conversationId,
      currentUserId:
          currentUserId,
    );
  }

  Future<ChatMessage> createAndSendMessage({
    required int senderId,
    required int recipientId,
    required String conversationId,
    required String text,
  }) async {
    final trimmedText =
        text.trim();

    if (trimmedText.isEmpty) {
      throw const ApiException(
        'Message cannot be empty.',
      );
    }

    final localId =
        _uuid.v4();

    final now =
        DateTime.now();

    var message =
        ChatMessage(
      localId:
          localId,

      serverId:
          null,

      senderId:
          senderId,

      recipientId:
          recipientId,

      conversationId:
          conversationId,

      text:
          trimmedText,

      createdAt:
          now,

      status:
          MessageStatus.pending,

      isMine:
          true,
    );

    await _database
        .insertMessage(
      message,
    );

    try {
      final result =
          await _messageService
              .sendMessage(
        recipientId:
            recipientId,

        clientMessageId:
            localId,

        message:
            trimmedText,
      );

      message =
          message.copyWith(
        serverId:
            result
                .serverMessageId,

        status:
            MessageStatus.sent,
      );

      await _database
          .updateMessage(
        message,
      );

      return message;
    } catch (_) {
      message =
          message.copyWith(
        status:
            MessageStatus.failed,
      );

      await _database
          .updateMessage(
        message,
      );

      return message;
    }
  }

  Future<int> receivePendingMessages({
    required int currentUserId,
  }) async {
    final pending =
        await _messageService
            .getPendingMessages();

    var receivedCount = 0;

    for (final serverMessage
        in pending) {
      if (serverMessage
              .recipientId !=
          currentUserId) {
        continue;
      }

      final existing =
          await _database
              .findByServerId(
        serverMessage
            .serverMessageId,
      );

      if (existing != null) {
        await _messageService
            .acknowledgeMessage(
          serverMessage
              .serverMessageId,
        );

        continue;
      }

      final conversationId =
          _makeConversationId(
        serverMessage.senderId,
        serverMessage.recipientId,
      );

      final localMessage =
          ChatMessage(
        localId:
            serverMessage
                .clientMessageId,

        serverId:
            serverMessage
                .serverMessageId,

        senderId:
            serverMessage.senderId,

        recipientId:
            serverMessage
                .recipientId,

        conversationId:
            conversationId,

        text:
            serverMessage.message,

        createdAt:
            serverMessage.createdAt,

        status:
            MessageStatus.delivered,

        isMine:
            serverMessage.senderId ==
                currentUserId,
      );

      await _database
          .insertMessage(
        localMessage,
      );

      await _messageService
          .acknowledgeMessage(
        serverMessage
            .serverMessageId,
      );

      receivedCount++;
    }

    return receivedCount;
  }

  /*
   * Called when the recipient opens the conversation.
   *
   * Every incoming delivered message in this
   * conversation is marked as read.
   */
  Future<void> markConversationAsRead({
    required String conversationId,
    required int currentUserId,
  }) async {
    final messages =
        await _database
            .getConversation(
      conversationId,
      currentUserId:
          currentUserId,
    );

    for (final message
        in messages) {
      if (message.isMine) {
        continue;
      }

      if (message.serverId == null) {
        continue;
      }

      if (message.status ==
              MessageStatus.read) {
        continue;
      }

      if (message.status !=
          MessageStatus.delivered) {
        continue;
      }

      try {
        await _messageService
            .markMessageRead(
          message.serverId!,
        );

        await _database
            .updateMessage(
          message.copyWith(
            status:
                MessageStatus.read,
          ),
        );
      } catch (_) {
        /*
         * If Internet is unavailable,
         * leave it delivered.
         *
         * It can be marked read during
         * a later synchronization.
         */
      }
    }
  }

  /*
   * Sender checks temporary server-side
   * read receipts.
   */
  Future<int> syncReadReceipts() async {
    final receipts =
        await _messageService
            .getPendingReadReceipts();

    var updatedCount = 0;

    for (final receipt
        in receipts) {
      final message =
          await _database
              .findByServerId(
        receipt.messageId,
      );

      if (message != null &&
          message.status !=
              MessageStatus.read) {
        await _database
            .updateMessage(
          message.copyWith(
            status:
                MessageStatus.read,
          ),
        );

        updatedCount++;
      }

      await _messageService
          .acknowledgeReadReceipt(
        receipt.id,
      );
    }

    return updatedCount;
  }

  Future<void> retryFailedMessage(
    ChatMessage message,
  ) async {
    if (message.status !=
        MessageStatus.failed) {
      return;
    }

    try {
      final result =
          await _messageService
              .sendMessage(
        recipientId:
            message.recipientId,

        clientMessageId:
            message.localId,

        message:
            message.text,
      );

      final updated =
          message.copyWith(
        serverId:
            result.serverMessageId,

        status:
            MessageStatus.sent,

        isMine: true,
      );

      await _database
          .updateMessage(
        updated,
      );
    } catch (_) {
      // Keep failed.
    }
  }

  String createConversationId(
    int userA,
    int userB,
  ) {
    return _makeConversationId(
      userA,
      userB,
    );
  }

  String _makeConversationId(
    int userA,
    int userB,
  ) {
    final ids = [
      userA,
      userB,
    ]..sort();

    return '${ids[0]}_${ids[1]}';
  }
}