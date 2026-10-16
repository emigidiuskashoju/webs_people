class UserPresence {
  final int userId;
  final bool online;
  final DateTime? lastSeenAt;
  final bool typing;
  final String? typingInConversation;

  const UserPresence({
    required this.userId,
    required this.online,
    required this.lastSeenAt,
    required this.typing,
    required this.typingInConversation,
  });

  factory UserPresence.fromJson(
    int userId,
    Map<String, dynamic> json,
  ) {
    final rawLastSeen = json['last_seen_at']?.toString();

    return UserPresence(
      userId: userId,
      online: json['online'] == true,
      lastSeenAt: (rawLastSeen == null || rawLastSeen.isEmpty)
          ? null
          : DateTime.tryParse(rawLastSeen),
      typing: json['typing'] == true,
      typingInConversation:
          json['typing_in_conversation']?.toString(),
    );
  }

  /// Human-readable string for the chat app bar and chats list.
  ///
  /// `isTypingHere` should be true when the caller is showing
  /// this user's chat screen and the user is typing in *that*
  /// conversation — then we return "typing…" instead of a
  /// status line.
  String statusLabel({
    required bool isTypingHere,
  }) {
    if (isTypingHere && typing) {
      return 'typing...';
    }

    if (online) {
      return 'online';
    }

    final seen = lastSeenAt;
    if (seen == null) {
      return 'offline';
    }

    final diff = DateTime.now().difference(seen);

    if (diff.inSeconds < 60) return 'last seen just now';
    if (diff.inMinutes < 60) {
      return 'last seen ${diff.inMinutes} min ago';
    }
    if (diff.inHours < 24) {
      return 'last seen ${diff.inHours} hr ago';
    }
    if (diff.inDays == 1) return 'last seen yesterday';
    if (diff.inDays < 7) {
      return 'last seen ${diff.inDays} days ago';
    }

    final day = seen.day.toString().padLeft(2, '0');
    final month = seen.month.toString().padLeft(2, '0');
    return 'last seen $day/$month';
  }
}