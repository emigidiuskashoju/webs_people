enum CallType {
  audio,
  video,
}

enum CallDirection {
  incoming,
  outgoing,
}

enum CallStatus {
  completed,
  missed,
  declined,
  failed,
}

class CallHistoryEntry {
  final String id;

  final int userId;

  final String name;

  final String phoneNumber;

  final CallType type;

  final CallDirection direction;

  final CallStatus status;

  final int durationSeconds;

  final DateTime timestamp;

  const CallHistoryEntry({
    required this.id,
    required this.userId,
    required this.name,
    required this.phoneNumber,
    required this.type,
    required this.direction,
    required this.status,
    required this.durationSeconds,
    required this.timestamp,
  });
}