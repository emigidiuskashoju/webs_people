import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/auth_storage.dart';

class MessageSendResult {
  final int serverMessageId;
  final String clientMessageId;

  const MessageSendResult({
    required this.serverMessageId,
    required this.clientMessageId,
  });
}

class PendingServerMessage {
  final int serverMessageId;

  final int senderId;
  final int recipientId;

  final String clientMessageId;
  final String message;

  final DateTime createdAt;

  const PendingServerMessage({
    required this.serverMessageId,
    required this.senderId,
    required this.recipientId,
    required this.clientMessageId,
    required this.message,
    required this.createdAt,
  });

  factory PendingServerMessage.fromJson(
    Map<String, dynamic> json,
  ) {
    final id = json['id'];
    final senderId = json['sender_id'];
    final recipientId = json['recipient_id'];

    if (id is! int ||
        senderId is! int ||
        recipientId is! int) {
      throw const ApiException(
        'Invalid pending message data.',
      );
    }

    return PendingServerMessage(
      serverMessageId: id,

      senderId: senderId,

      recipientId: recipientId,

      clientMessageId:
          json['client_message_id']
                  ?.toString() ??
              '',

      message:
          json['message']
                  ?.toString() ??
              '',

      createdAt:
          DateTime.parse(
        json['created_at']
            .toString(),
      ),
    );
  }
}

class ReadReceipt {
  final int id;
  final int messageId;

  const ReadReceipt({
    required this.id,
    required this.messageId,
  });

  factory ReadReceipt.fromJson(
    Map<String, dynamic> json,
  ) {
    final id = json['id'];
    final messageId =
        json['message_id'];

    if (id is! int ||
        messageId is! int) {
      throw const ApiException(
        'Invalid read receipt data.',
      );
    }

    return ReadReceipt(
      id: id,
      messageId: messageId,
    );
  }
}

class MessageService {
  final ApiClient _apiClient;
  final AuthStorage _storage;

  MessageService({
    ApiClient? apiClient,
    AuthStorage? storage,
  })  : _apiClient =
            apiClient ?? ApiClient(),
        _storage =
            storage ?? AuthStorage();

  Future<String> _getToken() async {
    final token =
        await _storage.getToken();

    if (token == null ||
        token.isEmpty) {
      throw const ApiException(
        'No authentication token was found.',
      );
    }

    return token;
  }

  Future<MessageSendResult> sendMessage({
    required int recipientId,
    required String clientMessageId,
    required String message,
  }) async {
    final token =
        await _getToken();

    final response =
        await _apiClient.post(
      ApiEndpoints.sendMessage,
      token: token,
      body: {
        'recipient_id':
            recipientId,

        'client_message_id':
            clientMessageId,

        'message':
            message,
      },
    );

    if (response
        is! Map<String, dynamic>) {
      throw const ApiException(
        'Invalid message response.',
      );
    }

    final serverId =
        response['server_message_id'];

    final returnedClientId =
        response['client_message_id'];

    if (serverId is! int ||
        returnedClientId is! String) {
      throw const ApiException(
        'Invalid message identifiers.',
      );
    }

    return MessageSendResult(
      serverMessageId:
          serverId,

      clientMessageId:
          returnedClientId,
    );
  }

  Future<List<PendingServerMessage>>
      getPendingMessages() async {
    final token =
        await _getToken();

    final response =
        await _apiClient.get(
      ApiEndpoints.pendingMessages,
      token: token,
    );

    if (response
        is! Map<String, dynamic>) {
      throw const ApiException(
        'Invalid pending messages response.',
      );
    }

    final messages =
        response['messages'];

    if (messages is! List) {
      throw const ApiException(
        'Invalid pending messages data.',
      );
    }

    return messages
        .whereType<
            Map<String, dynamic>>()
        .map(
          PendingServerMessage
              .fromJson,
        )
        .toList();
  }

  Future<void> acknowledgeMessage(
    int messageId,
  ) async {
    final token =
        await _getToken();

    await _apiClient.post(
      ApiEndpoints.acknowledgeMessage(
        messageId,
      ),
      token: token,
    );
  }

  /*
   * Recipient tells the server:
   *
   * "I have opened/read this message."
   */
  Future<void> markMessageRead(
    int messageId,
  ) async {
    final token =
        await _getToken();

    await _apiClient.post(
      ApiEndpoints.markMessageRead(
        messageId,
      ),
      token: token,
    );
  }

  /*
   * Sender checks whether any of their
   * messages have been read.
   */
  Future<List<ReadReceipt>>
      getPendingReadReceipts() async {
    final token =
        await _getToken();

    final response =
        await _apiClient.get(
      ApiEndpoints
          .pendingReadReceipts,
      token: token,
    );

    if (response
        is! Map<String, dynamic>) {
      throw const ApiException(
        'Invalid read receipt response.',
      );
    }

    final receipts =
        response['receipts'];

    if (receipts is! List) {
      throw const ApiException(
        'Invalid read receipt data.',
      );
    }

    return receipts
        .whereType<
            Map<String, dynamic>>()
        .map(
          ReadReceipt.fromJson,
        )
        .toList();
  }

  Future<void> acknowledgeReadReceipt(
    int receiptId,
  ) async {
    final token =
        await _getToken();

    await _apiClient.post(
      ApiEndpoints
          .acknowledgeReadReceipt(
        receiptId,
      ),
      token: token,
    );
  }
}