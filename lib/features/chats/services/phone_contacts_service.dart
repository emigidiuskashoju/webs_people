import 'package:flutter_contacts/flutter_contacts.dart';

import '../models/phone_contact.dart';

class PhoneContactsService {
  /// Default country calling code used when a phone number is stored
  /// in local format (e.g. 0629187797 -> +255629187797).
  static const String _defaultCountryCode = '255';

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

    final contacts = await FlutterContacts.getAll(
      properties: {
        ContactProperty.name,
        ContactProperty.phone,
      },
    );

    final results = <PhoneContact>[];

    for (final contact in contacts) {
      final name = (contact.displayName ?? '').trim();

      if (contact.phones.isEmpty) {
        continue;
      }

      for (final phone in contact.phones) {
        final normalized = normalizePhoneNumber(phone.number);

        if (normalized == null) {
          continue;
        }

        results.add(
          PhoneContact(
            name: name.isEmpty ? normalized : name,
            phoneNumber: normalized,
          ),
        );
      }
    }

    return _removeDuplicates(results);
  }

  /// Normalizes a raw phone number to the E.164 format `+<country><number>`.
  ///
  /// Handles:
  ///   - `+255629187797`  -> `+255629187797`
  ///   - `00255629187797` -> `+255629187797`
  ///   - `0629187797`     -> `+255629187797`  (local, prepends default country)
  ///   - `255629187797`   -> `+255629187797`  (country code without `+`)
  ///   - `(062) 918-7797` -> `+255629187797`
  ///
  /// Returns `null` if the number is invalid.
  String? normalizePhoneNumber(String value) {
    var phone = value.trim();

    if (phone.isEmpty) {
      return null;
    }

    // Strip spaces, dashes, parentheses, dots.
    phone = phone.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');

    // Convert 00 prefix to +.
    if (phone.startsWith('00')) {
      phone = '+${phone.substring(2)}';
    }

    // Local format: 0XXXXXXXXX -> +<country>XXXXXXXXX
    if (phone.startsWith('0')) {
      phone = '+$_defaultCountryCode${phone.substring(1)}';
    }

    // Country code without +: e.g. 255629187797 -> +255629187797
    if (!phone.startsWith('+')) {
      // Only treat it as a country-coded number if it looks long enough.
      if (RegExp(r'^\d{10,15}$').hasMatch(phone)) {
        phone = '+$phone';
      } else {
        return null;
      }
    }

    final digits = phone.substring(1);

    if (!RegExp(r'^\d{8,15}$').hasMatch(digits)) {
      return null;
    }

    return '+$digits';
  }

  List<PhoneContact> _removeDuplicates(List<PhoneContact> contacts) {
    final seen = <String>{};
    final result = <PhoneContact>[];

    for (final contact in contacts) {
      if (seen.contains(contact.phoneNumber)) {
        continue;
      }

      seen.add(contact.phoneNumber);
      result.add(contact);
    }

    return result;
  }
}