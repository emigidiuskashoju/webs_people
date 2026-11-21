import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../data/chat_repository.dart';

/// Resends messages that were queued while offline.
///
/// A message that fails to send is kept as "pending" (clock icon). This
/// service flushes the queue when the network comes back and, as a
/// safety net, on a slow timer — so queued messages go out on their own
/// without the user retrying.
class OutboxService {
  OutboxService._();
  static final OutboxService instance = OutboxService._();

  final ChatRepository _repository = ChatRepository();

  int? _userId;
  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _flushing = false;

  /// Begins watching for connectivity and queued messages for [userId].
  /// Safe to call many times.
  void start(int userId) {
    _userId = userId;

    _connSub ??= Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) flush();
    });

    _timer ??= Timer.periodic(const Duration(seconds: 20), (_) => flush());

    flush();
  }

  /// Tries to send any queued messages now.
  Future<void> flush() async {
    final userId = _userId;
    if (userId == null || _flushing) return;
    _flushing = true;
    try {
      await _repository.sendPendingMessages(userId);
    } catch (e) {
      debugPrint('OUTBOX: flush failed: $e');
    } finally {
      _flushing = false;
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _connSub?.cancel();
    _connSub = null;
  }
}
