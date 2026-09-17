class ConnectionRequest {
  final int id;
  final int senderId;
  final int receiverId;
  final String status;

  const ConnectionRequest({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
  });

  factory ConnectionRequest.fromJson(
    Map<String, dynamic> json,
  ) {
    return ConnectionRequest(
      id: int.parse(
        json['id'].toString(),
      ),
      senderId: int.parse(
        json['sender_id'].toString(),
      ),
      receiverId: int.parse(
        json['receiver_id'].toString(),
      ),
      status:
          json['status']?.toString() ??
          'pending',
    );
  }
}