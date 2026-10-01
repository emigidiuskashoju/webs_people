class DailyLocationCode {
  final String code;
  final DateTime expiresAt;

  const DailyLocationCode({
    required this.code,
    required this.expiresAt,
  });

  bool get isExpired =>
      DateTime.now().isAfter(
        expiresAt,
      );

  factory DailyLocationCode.fromJson(
    Map<String, dynamic> json,
  ) {
    return DailyLocationCode(
      code:
          json['code']?.toString() ?? '',

      expiresAt:
          DateTime.tryParse(
            json['expires_at']
                    ?.toString() ??
                '',
          ) ??
          DateTime.now(),
    );
  }
}