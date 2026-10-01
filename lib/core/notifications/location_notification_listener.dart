import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/chats/data/chat_repository.dart';
import '../../features/map/services/location_request_service.dart';

import '../storage/auth_storage.dart';
import 'notification_service.dart';

/// Polls the backend for incoming location requests while the
/// app is alive, and shows a notification for each one.
class LocationNotificationListener {
  LocationNotificationListener._();

  static final LocationNotificationListener instance =
      LocationNotificationListener._();

  final LocationRequestService _service =
      LocationRequestService();
  final ChatRepository _chatRepository = ChatRepository();
  final AuthStorage _authStorage = AuthStorage();

  Timer? _pollTimer;
  bool _initialized = false;

  /// Request ids already notified, so we don't fire twice.
  final Set<int> _notifiedRequestIds = <int>{};

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pollOnce(),
    );

    _pollOnce();

    debugPrint('LOCATION-LISTENER: started');
  }

  Future<void> _pollOnce() async {
    // ----------------------------------------------------------
    // Skip polling when there is no authentication token.
    //
    // This happens on the login, register, terms, and PIN
    // screens, or during an account switch. Without this guard
    // the poll would fail every few seconds with
    // "No authentication token is available" and flood the
    // logs.
    // ----------------------------------------------------------
    final token = await _authStorage.getToken();
    if (token == null || token.isEmpty) {
      return;
    }

    try {
      final requests = await _service.getPendingRequests();

      for (final request in requests) {
        if (_notifiedRequestIds.contains(request.id)) {
          continue;
        }

        // Only notify for requests where the current user is
        // the owner (i.e. someone is asking to see their
        // location).
        //
        // The pending endpoint already filters by owner, so
        // every request here is one we care about.
        //
        // Compute the conversation id so tapping the
        // notification can open the right chat.
        final conversationId =
            _chatRepository.createConversationId(
          request.ownerId,
          request.requesterId,
        );

        _notifiedRequestIds.add(request.id);

        final requesterName =
            request.requesterName?.trim() ?? '';

        await NotificationService.instance
            .showLocationRequestNotification(
          requestId: request.id,
          requesterId: request.requesterId,
          requesterName: requesterName.isNotEmpty
              ? requesterName
              : 'Someone',
          conversationId: conversationId,
        );

        debugPrint(
          'LOCATION-LISTENER: notified request=${request.id}',
        );
      }
    } catch (e) {
      debugPrint('LOCATION-LISTENER: poll failed: $e');
    }
  }

  /// Forget the notified set for a request after it has been
  /// accepted or denied, so future requests from the same user
  /// will notify again.
  void forget(int requestId) {
    _notifiedRequestIds.remove(requestId);
  }

  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }
}