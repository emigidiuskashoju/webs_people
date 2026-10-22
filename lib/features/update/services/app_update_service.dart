import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/app_release_info.dart';

class AppUpdateService {
  final ApiClient _apiClient;

  AppUpdateService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Returns the latest release info, or null if the server
  /// could not be reached or returned invalid data.
  ///
  /// Never throws — the caller should treat a null as
  /// "can't determine, let the user in".
  Future<AppReleaseInfo?> fetchLatestRelease() async {
    try {
      final response = await _apiClient
          .get(ApiEndpoints.appVersion)
          .timeout(const Duration(seconds: 8));

      if (response is! Map<String, dynamic>) return null;

      return AppReleaseInfo.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  /// Returns the app's own version code (e.g. 3 for "1.0.2+3").
  Future<int> getCurrentVersionCode() async {
    final info = await PackageInfo.fromPlatform();

    // package_info_plus exposes it as a string.
    return int.tryParse(info.buildNumber) ?? 0;
  }

  /// Convenience: true if the given [release] is newer than
  /// what is currently installed.
  ///
  /// Returns false if [release] is null (network failure)
  /// — we do not want to lock a user out because the server
  /// was briefly unreachable.
  Future<bool> isUpdateRequired(AppReleaseInfo? release) async {
    if (release == null) return false;

    final current = await getCurrentVersionCode();

    return release.versionCode > current;
  }
}