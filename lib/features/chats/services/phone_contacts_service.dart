import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../models/phone_contact.dart';

/// Contact-loading logs. Only printed in debug builds: debugPrint
/// still runs in the released app, and one line per contact slows
/// down loading on phones with large phone books.
void _log(String message) {
  if (kDebugMode) debugPrint(message);
}

class PhoneContactsService {
  /// Default country calling code used when a phone number is stored
  /// in local format (e.g. 0629187797 -> +255629187797).
  static const String _defaultCountryCode = '255';

  Future<List<PhoneContact>> getPhoneContacts() async {
    final permissionStatus =
        await FlutterContacts.permissions.request(
      PermissionType.read,
    );

    _log('=== CONTACTS DEBUG ===');
    _log('Permission status: $permissionStatus');

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

    _log('Total contacts read from device: ${contacts.length}');

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
        // Strict first (best for matching Webs users), then a loose
        // fallback so a contact saved in an unusual format still
        // shows up (in the Invite list) instead of vanishing.
        final number =
            normalizePhoneNumber(phone.number) ?? _looseNumber(phone.number);

        if (number == null) {
          skippedBadNumber++;
          _log('  Skipped (no usable digits): "$name" -> "${phone.number}"');
          continue;
        }

        results.add(
          PhoneContact(
            name: name.isEmpty ? number : name,
            phoneNumber: number,
          ),
        );
      }
    }

    _log('Skipped (no phone): $skippedNoPhone');
    _log('Skipped (invalid number): $skippedBadNumber');
    _log('Valid contacts before dedup: ${results.length}');

    final deduped = _removeDuplicates(results);
    _log('After dedup: ${deduped.length}');

    if (deduped.isNotEmpty) {
      _log('Sample (first 10):');
      for (final c in deduped.take(10)) {
        _log('  ${c.name} -> ${c.phoneNumber}');
      }
    }

    return deduped;
  }

  /// Best-effort number for a contact that failed strict
  /// normalization, so it is still shown (and can be invited)
  /// instead of being dropped. Any entry with at least 7 digits is
  /// kept; a plain local number still gets the Tanzania code.
  String? _looseNumber(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 7) return null;

    // Local mobile forms we recognise get the country code.
    if (digits.length == 10 && digits.startsWith('0')) {
      return '+$_defaultCountryCode${digits.substring(1)}';
    }
    if (digits.length == 9 &&
        (digits.startsWith('6') || digits.startsWith('7'))) {
      return '+$_defaultCountryCode$digits';
    }

    // Already looks international, or some other format: keep the
    // digits as-is behind a '+'. It simply won't match a Webs user,
    // which is fine for the Invite list.
    return '+$digits';
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

    // Saved without the 0: 712345678 -> +255712345678
    if (RegExp(r'^[67]\d{8}$').hasMatch(phone)) {
      phone = '+$_defaultCountryCode$phone';
    }

    // Code plus the local 0: +2550712345678 -> +255712345678
    final withTrunkZero =
        RegExp('^\\+?${_defaultCountryCode}0(\\d{9})\$').firstMatch(phone);
    if (withTrunkZero != null) {
      phone = '+$_defaultCountryCode${withTrunkZero.group(1)}';
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
