import 'package:flutter_contacts/flutter_contacts.dart';

import '../models/phone_contact.dart';

class PhoneContactsService {
  Future<List<PhoneContact>> getPhoneContacts() async {
    final permissionStatus =
        await FlutterContacts.permissions.request(
      PermissionType.read,
    );

    if (permissionStatus != PermissionStatus.granted) {
      throw Exception(
        'Contacts permission was not granted.',
      );
    }

    final contacts =
        await FlutterContacts.getAll(
      properties: {
        ContactProperty.name,
        ContactProperty.phone,
      },
    );

    final results =
        <PhoneContact>[];

    for (final contact in contacts) {
      final name =
          (contact.displayName ?? '').trim();

      if (contact.phones.isEmpty) {
        continue;
      }

      for (final phone in contact.phones) {
        final normalized =
            normalizePhoneNumber(
          phone.number,
        );

        if (normalized == null) {
          continue;
        }

        results.add(
          PhoneContact(
            name: name.isEmpty
                ? normalized
                : name,
            phoneNumber: normalized,
          ),
        );
      }
    }

    return _removeDuplicates(
      results,
    );
  }

  String? normalizePhoneNumber(
    String value,
  ) {
    var phone =
        value.trim();

    if (phone.isEmpty) {
      return null;
    }

    phone = phone.replaceAll(
      RegExp(r'[\s\-\(\)\.]'),
      '',
    );

    if (phone.startsWith('00')) {
      phone =
          '+${phone.substring(2)}';
    }

    if (!phone.startsWith('+')) {
      return null;
    }

    final digits =
        phone.substring(1);

    if (!RegExp(
      r'^\d{8,15}$',
    ).hasMatch(digits)) {
      return null;
    }

    return '+$digits';
  }

  List<PhoneContact> _removeDuplicates(
    List<PhoneContact> contacts,
  ) {
    final seen =
        <String>{};

    final result =
        <PhoneContact>[];

    for (final contact in contacts) {
      if (seen.contains(
        contact.phoneNumber,
      )) {
        continue;
      }

      seen.add(
        contact.phoneNumber,
      );

      result.add(contact);
    }

    return result;
  }
}