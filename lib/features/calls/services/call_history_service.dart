import '../../../core/storage/auth_storage.dart';
import '../../../core/storage/saved_account_storage.dart';
import '../data/call_repository.dart';
import '../models/call_record.dart';

class CallHistoryService {
  final AuthStorage _authStorage;
  final SavedAccountStorage _savedAccountStorage;
  final CallRepository _repository;

  CallHistoryService({
    AuthStorage? authStorage,
    SavedAccountStorage? savedAccountStorage,
    CallRepository? repository,
  })  : _authStorage =
            authStorage ?? AuthStorage(),
        _savedAccountStorage =
            savedAccountStorage ??
                SavedAccountStorage(),
        _repository =
            repository ?? CallRepository();

  Future<SavedAccount?> getActiveAccount() async {
    final token =
        await _authStorage.getToken();

    return _savedAccountStorage
        .getActiveAccount(token);
  }

  Future<List<CallRecord>> getHistory() async {
    final account =
        await getActiveAccount();

    if (account == null) {
      return [];
    }

    return _repository.getHistory(
      account.userId,
    );
  }

  Future<CallRecord?> createOutgoingCall({
    required String callId,
    required int remoteUserId,
    required String remoteName,
    required String remotePhoneNumber,
    required CallType type,
  }) async {
    final account =
        await getActiveAccount();

    if (account == null) {
      return null;
    }

    return _repository.createOutgoingCall(
      ownerUserId:
          account.userId,
      callId:
          callId,
      remoteUserId:
          remoteUserId,
      remoteName:
          remoteName,
      remotePhoneNumber:
          remotePhoneNumber,
      type:
          type,
    );
  }

  Future<CallRecord?> createIncomingCall({
    required String callId,
    required int remoteUserId,
    required String remoteName,
    required String remotePhoneNumber,
    required CallType type,
  }) async {
    final account =
        await getActiveAccount();

    if (account == null) {
      return null;
    }

    return _repository.createIncomingCall(
      ownerUserId:
          account.userId,
      callId:
          callId,
      remoteUserId:
          remoteUserId,
      remoteName:
          remoteName,
      remotePhoneNumber:
          remotePhoneNumber,
      type:
          type,
    );
  }

  CallRepository get repository =>
      _repository;
}