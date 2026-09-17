class ApiEndpoints {
  static const String baseUrl =
      'http://10.79.6.38:8001/api/v1';

  static const String health =
      '/health';

  static const String register =
      '/auth/register';

  static const String verifyEmail =
      '/auth/verify-email';

  static const String resendVerificationCode =
      '/auth/resend-code';

  static const String me =
      '/auth/me';

static const String contactMatch =
    '/contacts/match';

  static const String connectionRequests =
      '/connections/requests';

  static const String pendingConnectionRequests =
      '/connections/requests/pending';

  static const String connections =
      '/connections';

  static String acceptConnectionRequest(
    int requestId,
  ) {
    return '/connections/requests/$requestId/accept';
  }

  static String rejectConnectionRequest(
    int requestId,
  ) {
    return '/connections/requests/$requestId/reject';
  }

  static const String locationShare =
      '/location/share';

  static const String locationPeople =
      '/location/people';

static const String sendMessage =
    '/messages/send';

static const String pendingMessages =
    '/messages/pending';

static String acknowledgeMessage(
  int messageId,
) {
  return '/messages/$messageId/ack';
}

static String markMessageRead(
  int messageId,
) {
  return '/messages/$messageId/read';
}

static const String pendingReadReceipts =
    '/messages/read-receipts';

static String acknowledgeReadReceipt(
  int receiptId,
) {
  return '/messages/read-receipts/$receiptId/ack';
}

static const String startCall =
    '/calls/start';

static const String pendingCallEvents =
    '/calls/pending';

static String callEvents(
  String callId,
) {
  return '/calls/$callId/events';
}

static String sendCallEvent(
  String callId,
) {
  return '/calls/$callId/event';
}

static String acknowledgeCallEvent(
  int eventId,
) {
  return '/calls/events/$eventId/ack';
}
}