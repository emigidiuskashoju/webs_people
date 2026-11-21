enum MessageStatus {
  pending,
  sent,
  delivered,
  read,
  failed,
}

/// Kind of a chat message. Stored as a string so it matches the
/// server and survives unknown future values.
class MessageType {
  static const String text = 'text';
  static const String image = 'image';
  static const String audio = 'audio';
}

class ChatMessage {
  final String localId;
  final int? serverId;
  final int senderId;
  final int recipientId;
  final String conversationId;

  /// Text body, or the caption for a media message (may be empty).
  final String text;

  final DateTime createdAt;
  final MessageStatus status;
  final bool isMine;

  // --- media ---
  /// 'text', 'image' or 'audio'.
  final String type;

  /// Local file path once the media is downloaded/created on this phone.
  final String? mediaLocalPath;

  /// Server token to download the media (until it is pulled locally).
  final String? mediaToken;

  final String? mediaMime;

  /// Length of a voice note in milliseconds.
  final int? audioDurationMs;

  // --- reply ---
  /// Short preview of the message this one replies to (null if none).
  final String? replyPreview;

  /// Who wrote the replied-to message ('You' or the other name).
  final String? replySender;

  /// Type of the replied-to message ('text'/'image'/'audio').
  final String? replyType;

  const ChatMessage({
    required this.localId,
    required this.serverId,
    required this.senderId,
    required this.recipientId,
    required this.conversationId,
    required this.text,
    required this.createdAt,
    required this.status,
    required this.isMine,
    this.type = MessageType.text,
    this.mediaLocalPath,
    this.mediaToken,
    this.mediaMime,
    this.audioDurationMs,
    this.replyPreview,
    this.replySender,
    this.replyType,
  });

  bool get isText => type == MessageType.text;
  bool get isImage => type == MessageType.image;
  bool get isAudio => type == MessageType.audio;
  bool get hasReply => replyPreview != null;

  ChatMessage copyWith({
    String? localId,
    int? serverId,
    int? senderId,
    int? recipientId,
    String? conversationId,
    String? text,
    DateTime? createdAt,
    MessageStatus? status,
    bool? isMine,
    String? type,
    String? mediaLocalPath,
    String? mediaToken,
    String? mediaMime,
    int? audioDurationMs,
    String? replyPreview,
    String? replySender,
    String? replyType,
  }) {
    return ChatMessage(
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      conversationId: conversationId ?? this.conversationId,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      isMine: isMine ?? this.isMine,
      type: type ?? this.type,
      mediaLocalPath: mediaLocalPath ?? this.mediaLocalPath,
      mediaToken: mediaToken ?? this.mediaToken,
      mediaMime: mediaMime ?? this.mediaMime,
      audioDurationMs: audioDurationMs ?? this.audioDurationMs,
      replyPreview: replyPreview ?? this.replyPreview,
      replySender: replySender ?? this.replySender,
      replyType: replyType ?? this.replyType,
    );
  }
}
