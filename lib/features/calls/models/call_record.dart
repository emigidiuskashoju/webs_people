enum CallType {
  audio,
  video,
}

enum CallDirection {
  incoming,
  outgoing,
}

enum CallStatus {
  ringing,
  calling,
  connecting,
  connected,
  ended,
  declined,
  missed,
  failed,
}

class CallRecord {
  final String localId;
  final int ownerUserId;

  final String callId;

  final int remoteUserId;
  final String remoteName;
  final String remotePhoneNumber;

  final CallType type;
  final CallDirection direction;
  final CallStatus status;

  final DateTime startedAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;

  final int durationSeconds;

  const CallRecord({
    required this.localId,
    required this.ownerUserId,
    required this.callId,
    required this.remoteUserId,
    required this.remoteName,
    required this.remotePhoneNumber,
    required this.type,
    required this.direction,
    required this.status,
    required this.startedAt,
    required this.answeredAt,
    required this.endedAt,
    required this.durationSeconds,
  });

  CallRecord copyWith({
    String? localId,
    int? ownerUserId,
    String? callId,
    int? remoteUserId,
    String? remoteName,
    String? remotePhoneNumber,
    CallType? type,
    CallDirection? direction,
    CallStatus? status,
    DateTime? startedAt,
    DateTime? answeredAt,
    DateTime? endedAt,
    int? durationSeconds,
    bool clearAnsweredAt = false,
    bool clearEndedAt = false,
  }) {
    return CallRecord(
      localId: localId ?? this.localId,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      callId: callId ?? this.callId,
      remoteUserId:
          remoteUserId ?? this.remoteUserId,
      remoteName:
          remoteName ?? this.remoteName,
      remotePhoneNumber:
          remotePhoneNumber ??
              this.remotePhoneNumber,
      type: type ?? this.type,
      direction:
          direction ?? this.direction,
      status:
          status ?? this.status,
      startedAt:
          startedAt ?? this.startedAt,
      answeredAt: clearAnsweredAt
          ? null
          : answeredAt ?? this.answeredAt,
      endedAt: clearEndedAt
          ? null
          : endedAt ?? this.endedAt,
      durationSeconds:
          durationSeconds ??
              this.durationSeconds,
    );
  }
}