import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/auth_storage.dart';

class MessageSendResult {
  final int serverMessageId;
  final String clientMessageId;
  final DateTime? createdAt;

  const MessageSendResult({
    required this.serverMessageId,
    required this.clientMessageId,
    this.createdAt,
  });
}

class PendingServerMessage {
  final int serverMessageId;

  final int senderId;
  final int recipientId;

  final String clientMessageId;
  final String message;

  final DateTime createdAt;

  final String type;
  final String? mediaToken;
  final String? mediaMime;
  final int? audioDurationMs;
  final String? replyPreview;
  final String? replySender;
  final String? replyType;

  const PendingServerMessage({
    required this.serverMessageId,
    required this.senderId,
    required this.recipientId,
    required this.clientMessageId,
    required this.message,
    required this.createdAt,
    this.type = 'text',
    this.mediaToken,
    this.mediaMime,
    this.audioDurationMs,
    this.replyPreview,
    this.replySender,
    this.replyType,
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

      // Server sends UTC (…Z). Convert to the phone's local time so
      // the bubble shows the correct clock time, not UTC.
      createdAt:
          DateTime.parse(
        json['created_at']
            .toString(),
      ).toLocal(),
      type: json['type']?.toString() ?? 'text',
      mediaToken: json['media_token']?.toString(),
      mediaMime: json['media_mime']?.toString(),
      audioDurationMs: json['audio_duration_ms'] is int
          ? json['audio_duration_ms'] as int
          : int.tryParse(json['audio_duration_ms']?.toString() ?? ''),
      replyPreview: json['reply_to_preview']?.toString(),
      replySender: json['reply_to_sender']?.toString(),
      replyType: json['reply_to_type']?.toString(),
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

  /// Uploads an image or voice note; returns (token, mime).
  Future<({String token, String mime})> uploadMedia(
    File file,
    String kind, // 'image' or 'audio'
  ) async {
    final token = await _getToken();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.messageMediaUpload}'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';
    request.fields['kind'] = kind;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw ApiException(
        'Could not upload media (${streamed.statusCode}).',
        statusCode: streamed.statusCode,
      );
    }

    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) {
      throw const ApiException('Invalid media upload response.');
    }
    final mt = json['media_token']?.toString();
    final mime = json['media_mime']?.toString() ?? 'application/octet-stream';
    if (mt == null || mt.isEmpty) {
      throw const ApiException('Media upload did not return a token.');
    }
    return (token: mt, mime: mime);
  }

  /// Downloads media bytes for a token, or null if it is gone.
  Future<Uint8List?> downloadMedia(String mediaToken) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.messageMediaDownload(mediaToken)}',
      ),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode == 200) return response.bodyBytes;
    return null;
  }

  Future<MessageSendResult> sendMessage({
    required int recipientId,
    required String clientMessageId,
    required String message,
    String type = 'text',
    String? mediaToken,
    String? mediaMime,
    int? audioDurationMs,
    String? replyPreview,
    String? replySender,
    String? replyType,
  }) async {
    final token =
        await _getToken();

    final response =
        await _apiClient.post(
      ApiEndpoints.sendMessage,
      token: token,
      body: {
        'recipient_id': recipientId,
        'client_message_id': clientMessageId,
        'message': message,
        'type': type,
        if (mediaToken != null) 'media_token': mediaToken,
        if (mediaMime != null) 'media_mime': mediaMime,
        if (audioDurationMs != null) 'audio_duration_ms': audioDurationMs,
        if (replyPreview != null) 'reply_to_preview': replyPreview,
        if (replySender != null) 'reply_to_sender': replySender,
        if (replyType != null) 'reply_to_type': replyType,
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

    final rawCreatedAt =
        response['created_at']?.toString();

    final parsedCreatedAt =
        (rawCreatedAt == null || rawCreatedAt.isEmpty)
            ? null
            : DateTime.tryParse(rawCreatedAt);

    return MessageSendResult(
      serverMessageId:
          serverId,

      clientMessageId:
          returnedClientId,

      createdAt:
          parsedCreatedAt,
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

  /// Delivery/read status for the sender's own messages.
  /// Returns a map of serverMessageId -> (delivered, read).
  Future<Map<int, ({bool delivered, bool read})>> fetchMessageStatuses(
    List<int> messageIds,
  ) async {
    if (messageIds.isEmpty) return {};
    final token = await _getToken();

    final response = await _apiClient.post(
      ApiEndpoints.messageStatuses,
      token: token,
      body: {'message_ids': messageIds},
    );

    if (response is! Map<String, dynamic>) return {};
    final list = response['statuses'];
    if (list is! List) return {};

    final result = <int, ({bool delivered, bool read})>{};
    for (final item in list.whereType<Map<String, dynamic>>()) {
      final id = item['id'];
      if (id is! int) continue;
      result[id] = (
        delivered: item['delivered'] == true,
        read: item['read'] == true,
      );
    }
    return result;
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