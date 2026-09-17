class CallSession {
  final String callId;
  final int callerId;
  final int receiverId;
  final String callType;
  final String status;
  final DateTime createdAt;

  const CallSession({
    required this.callId,
    required this.callerId,
    required this.receiverId,
    required this.callType,
    required this.status,
    required this.createdAt,
  });

  factory CallSession.fromJson(
    Map<String, dynamic> json,
  ) {
    return CallSession(
      callId:
          json['call_id'].toString(),
      callerId: int.parse(
        json['caller_id'].toString(),
      ),
      receiverId: int.parse(
        json['receiver_id'].toString(),
      ),
      callType:
          json['call_type'].toString(),
      status:
          json['status'].toString(),
      createdAt: DateTime.parse(
        json['created_at'].toString(),
      ),
    );
  }
}