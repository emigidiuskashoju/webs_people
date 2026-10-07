import 'package:flutter/foundation.dart';
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

    debugPrint('=== CONTACTS DEBUG ===');
    debugPrint('Permission status: $permissionStatus');

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

    debugPrint('Total contacts read from device: ${contacts.length}');

    final results = <PhoneContact>[];
    var skippedNoPhone = 0;
    var skippedBadNumber = 0;

    for (final contact in contacts) {
      final name = (contact.displayName ?? '').trim();

      if (contact.phones.isEmpty) {
        skippedNoPhone++;
        continue;
      }

      for (final phone in contact.phones) {
        final normalized = normalizePhoneNumber(phone.number);

        if (normalized == null) {
          skippedBadNumber++;
          debugPrint('  Skipped invalid: "$name" -> "${phone.number}"');
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

    debugPrint('Skipped (no phone): $skippedNoPhone');
    debugPrint('Skipped (invalid number): $skippedBadNumber');
    debugPrint('Valid contacts before dedup: ${results.length}');

    final deduped = _removeDuplicates(results);
    debugPrint('After dedup: ${deduped.length}');

    if (deduped.isNotEmpty) {
      debugPrint('Sample (first 10):');
      for (final c in deduped.take(10)) {
        debugPrint('  ${c.name} -> ${c.phoneNumber}');
      }
    }

    return deduped;
  }

  String? normalizePhoneNumber(String value) {
    var phone = value.trim();

    if (phone.isEmpty) {
      return null;
    }

    phone = phone.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');

    if (phone.startsWith('00')) {
      phone = '+${phone.substring(2)}';
    }

    if (phone.startsWith('0')) {
      phone = '+$_defaultCountryCode${phone.substring(1)}';
    }

    if (!phone.startsWith('+')) {
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
