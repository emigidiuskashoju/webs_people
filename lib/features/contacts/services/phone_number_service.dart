class PhoneNumberService {
  String normalize(String value) {
    var phone =
        value.trim();

    phone = phone.replaceAll(
      RegExp(r'[\s\-\(\)]'),
      '',
    );

    if (phone.startsWith('00')) {
      phone =
          '+${phone.substring(2)}';
    }

    return phone;
  }

  List<String> normalizeMany(
    List<String> numbers,
  ) {
    final normalized =
        numbers
            .map(normalize)
            .where(
              (number) =>
                  number.isNotEmpty,
            )
            .toSet()
            .toList();

    return normalized;
  }
}