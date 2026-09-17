enum MessageStatus {
  pending,
  sent,
  delivered,
  read,
  failed,
}

class ChatMessage {
  final String localId;
  final int? serverId;
  final int senderId;
  final int recipientId;
  final String conversationId;
  final String text;
  final DateTime createdAt;
  final MessageStatus status;
  final bool isMine;

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
  });

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
  }) {
    return ChatMessage(
      localId:
          localId ?? this.localId,

      serverId:
          serverId ?? this.serverId,

      senderId:
          senderId ?? this.senderId,

      recipientId:
          recipientId ?? this.recipientId,

      conversationId:
          conversationId ?? this.conversationId,

      text:
          text ?? this.text,

      createdAt:
          createdAt ?? this.createdAt,

      status:
          status ?? this.status,

      isMine:
          isMine ?? this.isMine,
    );
  }
}