class ConnectionRequest {
  final int id;
  final int senderId;
  final int receiverId;
  final String? senderName;
  final String status;
  final DateTime? createdAt;

  const ConnectionRequest({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.senderName,
    required this.status,
    required this.createdAt,
  });

  factory ConnectionRequest.fromJson(
    Map<String, dynamic> json,
  ) {
    final id = _toInt(json['id']);
    final senderId = _toInt(
      json['sender_id'],
    );
    final receiverId = _toInt(
      json['receiver_id'],
    );

    if (id == null ||
        senderId == null ||
        receiverId == null) {
      throw const FormatException(
        'Invalid connection request data.',
      );
    }

    return ConnectionRequest(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      senderName:
          json['sender_name']?.toString(),
      status:
          json['status']?.toString() ?? 'pending',
      createdAt: _toDateTime(
        json['created_at'],
      ),
    );
  }

  static int? _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString() ?? '',
    );
  }

  static DateTime? _toDateTime(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(
      value.toString(),
    );
  }
}