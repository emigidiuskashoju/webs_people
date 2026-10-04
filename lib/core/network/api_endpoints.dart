class ApiEndpoints {
  static const String baseUrl =
    'http://134.209.65.175/api/v1';

  static const String health =
      '/health';

  // ============================================================
  // AUTH
  // ============================================================

  static const String register =
      '/auth/register';

  static const String verifyEmail =
      '/auth/verify-email';

  static const String setPassword =
      '/auth/set-password';

  static const String resendVerificationCode =
      '/auth/resend-code';

  static const String login =
      '/auth/login';

  static const String logout =
      '/auth/logout';

  static const String me =
      '/auth/me';

  // ============================================================
  // PROFILE
  // ============================================================

  static const String profile =
      '/profile';

  static const String profilePhoto =
      '/profile/photo';

  // ============================================================
  // DEVICES
  // ============================================================

  static const String devices =
      '/devices';

  static const String recovery =
      '/devices/recovery';

  static String device(int deviceId) =>
      '/devices/$deviceId';

  static String deviceHeartbeat(
    int deviceId,
  ) =>
      '/devices/$deviceId/heartbeat';

  static String deviceLocation(
    int deviceId,
  ) =>
      '/devices/$deviceId/location';

  static String deviceLocations(
    int deviceId,
  ) =>
      '/devices/$deviceId/locations';

  static String enableLostMode(
    int deviceId,
  ) =>
      '/devices/$deviceId/lost-mode';

  static String disableLostMode(
    int deviceId,
  ) =>
      '/devices/$deviceId/lost-mode';

  static String deviceCommands(
    int deviceId,
  ) =>
      '/devices/$deviceId/commands';

  static String acknowledgeDeviceCommand(
    int deviceId,
    int commandId,
  ) =>
      '/devices/$deviceId/commands/$commandId/ack';

  // ============================================================
  // CONTACTS
  // ============================================================

  static const String contactMatch =
      '/contacts/match';

  // ============================================================
  // CONNECTIONS
  // ============================================================

  static const String connectionRequests =
      '/connections/requests';

  static const String pendingConnectionRequests =
      '/connections/requests/pending';

  static const String connections =
      '/connections';

  static String acceptConnectionRequest(
    int requestId,
  ) =>
      '/connections/requests/$requestId/accept';

  static String rejectConnectionRequest(
    int requestId,
  ) =>
      '/connections/requests/$requestId/reject';

    // ============================================================
  // LOCATION
  // ============================================================

  static const String locationCode =
      '/location/codes';

  static const String locationRequests =
      '/location/requests';

  static const String pendingLocationRequests =
      '/location/requests/pending';

  static String locationConversationRequests(
    int userId,
  ) =>
      '/location/requests/chat/$userId';

  static String acceptLocationRequest(
    int requestId,
  ) =>
      '/location/requests/$requestId/accept';

  static String denyLocationRequest(
    int requestId,
  ) =>
      '/location/requests/$requestId/deny';

  static String locationRequestLocation(
    int requestId,
  ) =>
      '/location/requests/$requestId/location';

  static const String customRoutes =
      '/location/custom-routes';

  static String customRoute(
    int locationRequestId,
  ) =>
      '/location/custom-routes/$locationRequestId';

  // ------------------------------------------------------------
  // LOCATION SHARING
  // ------------------------------------------------------------

  static const String locationShare =
      '/location/share';

  static const String locationPeople =
      '/location/people';

  // ============================================================
  // MESSAGES
  // ============================================================

  static const String sendMessage =
      '/messages/send';

  static const String pendingMessages =
      '/messages/pending';

  static String acknowledgeMessage(
    int messageId,
  ) =>
      '/messages/$messageId/ack';

  static String markMessageRead(
    int messageId,
  ) =>
      '/messages/$messageId/read';

  static const String pendingReadReceipts =
      '/messages/read-receipts';

  static String acknowledgeReadReceipt(
    int receiptId,
  ) =>
      '/messages/read-receipts/$receiptId/ack';

  // ============================================================
  // CALLS
  // ============================================================

  static const String startCall =
      '/calls/start';

  static const String pendingCallEvents =
      '/calls/pending';

  static String callEvents(
    String callId,
  ) =>
      '/calls/$callId/events';

  static String sendCallEvent(
    String callId,
  ) =>
      '/calls/$callId/event';

  static String acknowledgeCallEvent(
    int eventId,
  ) =>
      '/calls/events/$eventId/ack';

  static const String fcmToken = '/fcm-token';
}