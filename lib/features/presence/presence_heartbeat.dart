import 'dart:async';

import 'package:flutter/foundation.dart';

import 'services/presence_service.dart';

/// Global heartbeat that keeps this device's presence alive
/// on the server.
///
/// - Fires once immediately on [start].
/// - Then fires every [_interval] while running.
/// - [setTypingConversation] triggers an immediate beat so
///   "typing..." appears fast on the other side.
/// - [stop] cancels the timer (called on logout).
class PresenceHeartbeat {
  PresenceHeartbeat._();

  static final PresenceHeartbeat instance = PresenceHeartbeat._();

  static const Duration _interval = Duration(seconds: 25);

  final PresenceService _service = PresenceService();

  Timer? _timer;
  String? _typingConversation;

  bool get isRunning => _timer != null;

  Future<void> start() async {
    if (_timer != null) return;

    await _beat();

    _timer = Timer.periodic(
      _interval,
      (_) => _beat(),
    );

    debugPrint('PRESENCE: heartbeat started');
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _typingConversation = null;

    debugPrint('PRESENCE: heartbeat stopped');
  }

  /// Called by the chat screen when the user begins typing.
  /// Passing null means the user stopped typing.
  Future<void> setTypingConversation(
    String? conversationId,
  ) async {
    if (_typingConversation == conversationId) return;

    _typingConversation = conversationId;

    await _beat();
  }

  Future<void> _beat() async {
    try {
      await _service.heartbeat(
        typingInConversation: _typingConversation,
      );
    } catch (e) {
      debugPrint('PRESENCE: heartbeat failed: $e');
    }
  }
}