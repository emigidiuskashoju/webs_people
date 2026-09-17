import 'package:uuid/uuid.dart';

import '../models/call_record.dart';
import 'call_database.dart';

class CallRepository {
  final CallDatabase _database;
  final Uuid _uuid;

  CallRepository({
    CallDatabase? database,
    Uuid? uuid,
  })  : _database =
            database ?? CallDatabase(),
        _uuid =
            uuid ?? const Uuid();

  Future<CallRecord> createOutgoingCall({
    required int ownerUserId,
    required String callId,
    required int remoteUserId,
    required String remoteName,
    required String remotePhoneNumber,
    required CallType type,
  }) async {
    final call = CallRecord(
      localId: _uuid.v4(),
      ownerUserId: ownerUserId,
      callId: callId,
      remoteUserId: remoteUserId,
      remoteName: remoteName,
      remotePhoneNumber:
          remotePhoneNumber,
      type: type,
      direction: CallDirection.outgoing,
      status: CallStatus.calling,
      startedAt: DateTime.now(),
      answeredAt: null,
      endedAt: null,
      durationSeconds: 0,
    );

    await _database.insertCall(call);

    return call;
  }

  Future<CallRecord> createIncomingCall({
    required int ownerUserId,
    required String callId,
    required int remoteUserId,
    required String remoteName,
    required String remotePhoneNumber,
    required CallType type,
  }) async {
    final call = CallRecord(
      localId: _uuid.v4(),
      ownerUserId: ownerUserId,
      callId: callId,
      remoteUserId: remoteUserId,
      remoteName: remoteName,
      remotePhoneNumber:
          remotePhoneNumber,
      type: type,
      direction: CallDirection.incoming,
      status: CallStatus.ringing,
      startedAt: DateTime.now(),
      answeredAt: null,
      endedAt: null,
      durationSeconds: 0,
    );

    await _database.insertCall(call);

    return call;
  }

  Future<CallRecord?> findByCallId(
    String callId,
    int ownerUserId,
  ) {
    return _database.findByCallIdForOwner(
      callId,
      ownerUserId,
    );
  }

  Future<void> updateStatus({
    required String localId,
    required CallStatus status,
    DateTime? answeredAt,
    DateTime? endedAt,
    int? durationSeconds,
  }) async {
    final existing =
        await _database.findByLocalId(
      localId,
    );

    if (existing == null) {
      return;
    }

    final updated = existing.copyWith(
      status: status,
      answeredAt:
          answeredAt,
      endedAt:
          endedAt,
      durationSeconds:
          durationSeconds,
    );

    await _database.updateCall(
      updated,
    );
  }

  Future<void> markConnected(
    String localId,
  ) async {
    final existing =
        await _database.findByLocalId(
      localId,
    );

    if (existing == null) {
      return;
    }

    await _database.updateCall(
      existing.copyWith(
        status:
            CallStatus.connected,
        answeredAt:
            existing.answeredAt ??
                DateTime.now(),
      ),
    );
  }

  Future<void> markEnded(
    String localId,
  ) async {
    final existing =
        await _database.findByLocalId(
      localId,
    );

    if (existing == null) {
      return;
    }

    final endedAt = DateTime.now();

    var durationSeconds = 0;

    if (existing.answeredAt != null) {
      durationSeconds =
          endedAt
              .difference(
                existing.answeredAt!,
              )
              .inSeconds;

      if (durationSeconds < 0) {
        durationSeconds = 0;
      }
    }

    await _database.updateCall(
      existing.copyWith(
        status:
            CallStatus.ended,
        endedAt:
            endedAt,
        durationSeconds:
            durationSeconds,
      ),
    );
  }

  Future<void> markDeclined(
    String localId,
  ) async {
    final existing =
        await _database.findByLocalId(
      localId,
    );

    if (existing == null) {
      return;
    }

    await _database.updateCall(
      existing.copyWith(
        status:
            CallStatus.declined,
        endedAt:
            DateTime.now(),
      ),
    );
  }

  Future<void> markMissed(
    String localId,
  ) async {
    final existing =
        await _database.findByLocalId(
      localId,
    );

    if (existing == null) {
      return;
    }

    await _database.updateCall(
      existing.copyWith(
        status:
            CallStatus.missed,
        endedAt:
            DateTime.now(),
      ),
    );
  }

  Future<List<CallRecord>> getHistory(
    int ownerUserId,
  ) {
    return _database.getCallsForOwner(
      ownerUserId,
    );
  }

  Future<void> deleteHistory(
    int ownerUserId,
  ) {
    return _database.deleteCallsForOwner(
      ownerUserId,
    );
  }

  Future<void> close() {
    return _database.close();
  }
}