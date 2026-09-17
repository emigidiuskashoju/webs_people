import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/auth_storage.dart';

class CallEvent {
  final int id;
  final String callId;

  final int senderId;
  final int recipientId;

  final String event;

  final Map<String, dynamic> payload;

  const CallEvent({
    required this.id,
    required this.callId,
    required this.senderId,
    required this.recipientId,
    required this.event,
    required this.payload,
  });

  factory CallEvent.fromJson(
    Map<String, dynamic> json,
  ) {
    final id =
        json['id'];

    final senderId =
        json['sender_id'];

    final recipientId =
        json['recipient_id'];

    if (id is! int ||
        senderId is! int ||
        recipientId is! int) {
      throw const ApiException(
        'Invalid call event.',
      );
    }

    return CallEvent(
      id: id,
      callId:
          json['call_id']
              ?.toString() ??
              '',
      senderId:
          senderId,
      recipientId:
          recipientId,
      event:
          json['event']
              ?.toString() ??
              '',
      payload:
          json['payload'] is Map
              ? Map<String, dynamic>.from(
                  json['payload'] as Map,
                )
              : {},
    );
  }
}

class CallStartResult {
  final String callId;
  final String type;

  const CallStartResult({
    required this.callId,
    required this.type,
  });
}

class CallSignalingService {
  final ApiClient _apiClient;
  final AuthStorage _authStorage;

  CallSignalingService({
    ApiClient? apiClient,
    AuthStorage? authStorage,
  })  : _apiClient =
            apiClient ?? ApiClient(),
        _authStorage =
            authStorage ?? AuthStorage();

  Future<String> _token() async {
    final token =
        await _authStorage.getToken();

    if (token == null ||
        token.isEmpty) {
      throw const ApiException(
        'No authentication token was found.',
      );
    }

    return token;
  }

  Future<CallStartResult> startCall({
    required int recipientId,
    required String type,
  }) async {
    final token =
        await _token();

    final response =
        await _apiClient.post(
      ApiEndpoints.startCall,
      token: token,
      body: {
        'recipient_id':
            recipientId,
        'type':
            type,
      },
    );

    if (response
        is! Map<String, dynamic>) {
      throw const ApiException(
        'Invalid call start response.',
      );
    }

    final callId =
        response['call_id'];

    if (callId is! String ||
        callId.isEmpty) {
      throw const ApiException(
        'The server did not return a call ID.',
      );
    }

    return CallStartResult(
      callId:
          callId,
      type:
          response['type']
                  ?.toString() ??
              type,
    );
  }

  Future<List<CallEvent>>
      getPendingEvents() async {
    final token =
        await _token();

    final response =
        await _apiClient.get(
      ApiEndpoints.pendingCallEvents,
      token: token,
    );

    return _parseEvents(
      response,
    );
  }

  Future<List<CallEvent>>
      getCallEvents(
    String callId,
  ) async {
    final token =
        await _token();

    final response =
        await _apiClient.get(
      ApiEndpoints.callEvents(
        callId,
      ),
      token: token,
    );

    return _parseEvents(
      response,
    );
  }

  Future<void> sendEvent({
    required String callId,
    required int recipientId,
    required String event,
    Map<String, dynamic>? payload,
  }) async {
    final token =
        await _token();

    await _apiClient.post(
      ApiEndpoints.sendCallEvent(
        callId,
      ),
      token: token,
      body: {
        'recipient_id':
            recipientId,
        'event':
            event,
        'payload':
            payload ?? {},
      },
    );
  }

  Future<void> acknowledgeEvent(
    int eventId,
  ) async {
    final token =
        await _token();

    await _apiClient.post(
      ApiEndpoints.acknowledgeCallEvent(
        eventId,
      ),
      token: token,
    );
  }

  List<CallEvent> _parseEvents(
    dynamic response,
  ) {
    if (response
        is! Map<String, dynamic>) {
      throw const ApiException(
        'Invalid call events response.',
      );
    }

    final events =
        response['events'];

    if (events is! List) {
      throw const ApiException(
        'Invalid call events data.',
      );
    }

    return events
        .whereType<
            Map<String, dynamic>>()
        .map(
          CallEvent.fromJson,
        )
        .toList();
  }
}