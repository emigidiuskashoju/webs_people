import 'package:flutter_contacts/flutter_contacts.dart';

import '../models/phone_contact.dart';

class ContactService {
  Future<bool> requestPermission() async {
    final status =
        await FlutterContacts.permissions.request(
      PermissionType.read,
    );

    return status ==
        PermissionStatus.granted;
  }

  Future<List<PhoneContact>> getContacts() async {
    final permission =
        await requestPermission();

    if (!permission) {
      throw Exception(
        'Contacts permission was not granted.',
      );
    }

    final contacts =
        await FlutterContacts.getAll(
      properties: {
        ContactProperty.phone,
      },
    );

    return contacts.map((contact) {
      final numbers = contact.phones
          .map(
            (phone) =>
                (phone.number ?? '').trim(),
          )
          .where(
            (number) =>
                number.isNotEmpty,
          )
          .toList();

      return PhoneContact(
        displayName:
            (contact.displayName ?? '').trim(),
        phoneNumbers: numbers,
      );
    }).toList();
  }

  Future<List<String>> getPhoneNumbers() async {
    final contacts =
        await getContacts();

    final numbers = <String>[];

    for (final contact in contacts) {
      numbers.addAll(
        contact.phoneNumbers,
      );
    }

    return numbers;
  }
}