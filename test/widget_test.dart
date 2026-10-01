import 'package:flutter_test/flutter_test.dart';

import 'package:webs_people/features/auth/models/user_model.dart';

void main() {
  test(
    'UserModel converts JSON correctly',
    () {
      final json = {
        'id': 1,
        'name': 'Test User',
        'phone_number':
            '+255700000000',
        'phone_verified_at': null,
      };

      final user =
          UserModel.fromJson(json);

      expect(user.id, 1);

      expect(
        user.name,
        'Test User',
      );

      expect(
        user.phoneNumber,
        '+255700000000',
      );

      expect(
        user.phoneVerifiedAt,
        isNull,
      );
    },
  );

  test(
    'UserModel converts back to JSON',
    () {
      const user = UserModel(
        id: 5,
        name: 'John',
        phoneNumber:
            '+255700000001',
      );

      final json =
          user.toJson();

      expect(
        json['id'],
        5,
      );

      expect(
        json['name'],
        'John',
      );

      expect(
        json['phone_number'],
        '+255700000001',
      );
    },
  );
}