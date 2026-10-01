import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SavedAccount {
  final int userId;
  final String name;
  final String email;
  final String phoneNumber;
  final String token;

  const SavedAccount({
    required this.userId,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.token,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'email': email,
      'phone_number': phoneNumber,
      'token': token,
    };
  }

  factory SavedAccount.fromJson(
    Map<String, dynamic> json,
  ) {
    final userId = json['user_id'];

    if (userId is! int) {
      throw const FormatException(
        'Invalid saved account user ID.',
      );
    }

    return SavedAccount(
      userId: userId,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phoneNumber:
          json['phone_number']?.toString() ?? '',
      token: json['token']?.toString() ?? '',
    );
  }
}

class SavedAccountStorage {
  static const String _accountsKey =
      'webs_saved_accounts';

  final FlutterSecureStorage _storage;

  SavedAccountStorage({
    FlutterSecureStorage? storage,
  }) : _storage =
            storage ?? const FlutterSecureStorage();

  Future<List<SavedAccount>> getAccounts() async {
    final value = await _storage.read(
      key: _accountsKey,
    );

    if (value == null || value.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(value);

      if (decoded is! List) {
        return [];
      }

      final accounts = <SavedAccount>[];

      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }

        try {
          final account =
              SavedAccount.fromJson(
            Map<String, dynamic>.from(item),
          );

          if (account.token.isEmpty) {
            continue;
          }

          accounts.add(account);
        } catch (_) {
          continue;
        }
      }

      return accounts;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAccount(
    SavedAccount account,
  ) async {
    final accounts = await getAccounts();

    final existingIndex = accounts.indexWhere(
      (savedAccount) =>
          savedAccount.userId == account.userId,
    );

    if (existingIndex >= 0) {
      accounts[existingIndex] = account;
    } else {
      accounts.add(account);
    }

    await _saveAccounts(accounts);
  }

  Future<void> removeAccount(
    int userId,
  ) async {
    final accounts = await getAccounts();

    accounts.removeWhere(
      (account) =>
          account.userId == userId,
    );

    await _saveAccounts(accounts);
  }

  Future<void> _saveAccounts(
    List<SavedAccount> accounts,
  ) async {
    final encoded = jsonEncode(
      accounts
          .map(
            (account) => account.toJson(),
          )
          .toList(),
    );

    await _storage.write(
      key: _accountsKey,
      value: encoded,
    );
  }

Future<SavedAccount?> getActiveAccount(
  String? activeToken,
) async {
  if (activeToken == null ||
      activeToken.isEmpty) {
    return null;
  }

  final accounts =
      await getAccounts();

  for (final account in accounts) {
    if (account.token == activeToken) {
      return account;
    }
  }

  return null;
}

}