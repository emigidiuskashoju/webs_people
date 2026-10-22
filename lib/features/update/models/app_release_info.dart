class AppReleaseInfo {
  final int versionCode;
  final String versionName;
  final String downloadUrl;
  final String? releaseNotes;
  final bool critical;

  const AppReleaseInfo({
    required this.versionCode,
    required this.versionName,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.critical,
  });

  factory AppReleaseInfo.fromJson(Map<String, dynamic> json) {
    final versionCode = json['version_code'];
    final versionName = json['version_name']?.toString() ?? '';
    final downloadUrl = json['download_url']?.toString() ?? '';

    if (versionCode is! int ||
        versionName.isEmpty ||
        downloadUrl.isEmpty) {
      throw const FormatException('Invalid app release payload.');
    }

    return AppReleaseInfo(
      versionCode: versionCode,
      versionName: versionName,
      downloadUrl: downloadUrl,
      releaseNotes: json['release_notes']?.toString(),
      critical: json['critical'] == true,
    );
  }
}