import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:webs_people/features/calls/data/call_database.dart';
import 'package:webs_people/features/calls/models/call_record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /*
   * Flutter tests run on the Dart VM rather than
   * inside Android/iOS.
   *
   * sqflite_common_ffi provides SQLite support for
   * this test environment.
   */
  sqfliteFfiInit();

  databaseFactory = databaseFactoryFfi;

  group('CallDatabase', () {
    test(
      'stores call history separately by owner account',
      () async {
        final database =
            CallDatabase();

        const accountA = 1001;
        const accountB = 2002;

        final callA =
            CallRecord(
          localId:
              'local-a',

          ownerUserId:
              accountA,

          callId:
              'call-a',

          remoteUserId:
              accountB,

          remoteName:
              'Account B',

          remotePhoneNumber:
              '+255700000002',

          type:
              CallType.audio,

          direction:
              CallDirection.outgoing,

          status:
              CallStatus.ended,

          startedAt:
              DateTime(
            2026,
            1,
            1,
            10,
            0,
          ),

          answeredAt:
              DateTime(
            2026,
            1,
            1,
            10,
            0,
            5,
          ),

          endedAt:
              DateTime(
            2026,
            1,
            1,
            10,
            1,
          ),

          durationSeconds:
              55,
        );

        final callB =
            CallRecord(
          localId:
              'local-b',

          ownerUserId:
              accountB,

          callId:
              'call-b',

          remoteUserId:
              accountA,

          remoteName:
              'Account A',

          remotePhoneNumber:
              '+255700000001',

          type:
              CallType.audio,

          direction:
              CallDirection.incoming,

          status:
              CallStatus.ended,

          startedAt:
              DateTime(
            2026,
            1,
            1,
            11,
            0,
          ),

          answeredAt:
              DateTime(
            2026,
            1,
            1,
            11,
            0,
            5,
          ),

          endedAt:
              DateTime(
            2026,
            1,
            1,
            11,
            2,
          ),

          durationSeconds:
              115,
        );

        await database.insertCall(
          callA,
        );

        await database.insertCall(
          callB,
        );

        final historyA =
            await database.getCallsForOwner(
          accountA,
        );

        final historyB =
            await database.getCallsForOwner(
          accountB,
        );

        /*
         * Account A must see only
         * Account A's call.
         */
        expect(
          historyA.length,
          1,
        );

        expect(
          historyA.first.callId,
          'call-a',
        );

        expect(
          historyA.first.ownerUserId,
          accountA,
        );

        expect(
          historyA.first.remoteUserId,
          accountB,
        );

        /*
         * Account B must see only
         * Account B's call.
         */
        expect(
          historyB.length,
          1,
        );

        expect(
          historyB.first.callId,
          'call-b',
        );

        expect(
          historyB.first.ownerUserId,
          accountB,
        );

        expect(
          historyB.first.remoteUserId,
          accountA,
        );

        /*
         * Make absolutely sure that A's history
         * does not contain B's call.
         */
        expect(
          historyA.any(
            (call) =>
                call.ownerUserId ==
                accountB,
          ),
          false,
        );

        /*
         * Make absolutely sure that B's history
         * does not contain A's call.
         */
        expect(
          historyB.any(
            (call) =>
                call.ownerUserId ==
                accountA,
          ),
          false,
        );

        await database.close();
      },
    );
  });
}