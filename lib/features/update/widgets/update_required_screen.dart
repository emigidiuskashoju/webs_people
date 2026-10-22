import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/webs_colors.dart';
import '../models/app_release_info.dart';

class UpdateRequiredScreen extends StatelessWidget {
  final AppReleaseInfo release;

  const UpdateRequiredScreen({
    super.key,
    required this.release,
  });

  Future<void> _openDownload() async {
    final uri = Uri.tryParse(release.downloadUrl);
    if (uri == null) return;

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final notes = release.releaseNotes?.trim();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: WebsColors.softGreen(context),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.system_update_alt,
                  size: 56,
                  color: WebsColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Update required',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: WebsColors.textDark(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Version ${release.versionName} is available. '
                'Please update to continue using Webs.',
                style: TextStyle(
                  fontSize: 15,
                  color: WebsColors.textLight(context),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              if (notes != null && notes.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: WebsColors.softGreen(context),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What\'s new',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: WebsColors.textDark(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notes,
                        style: TextStyle(
                          fontSize: 13,
                          color: WebsColors.textLight(context),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _openDownload,
                  icon: const Icon(Icons.download),
                  label: const Text(
                    'Update now',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: WebsColors.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'You will not lose any messages when you update.',
                style: TextStyle(
                  fontSize: 12,
                  color: WebsColors.textLight(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}