import 'package:flutter/material.dart';

import '../../core/theme/webs_colors.dart';
import '../../core/widgets/webs_background.dart';

class AboutWebsPeopleScreen extends StatelessWidget {
  const AboutWebsPeopleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('About Webs')),
      body: WebsBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
            children: [
              const SizedBox(height: 20),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: WebsColors.softGreen(context),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.hub,
                    color: WebsColors.primaryGreen,
                    size: 56,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Webs',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: WebsColors.textDark(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Connect privately with people you know.',
                textAlign: TextAlign.center,
                style: TextStyle(color: WebsColors.textLight(context)),
              ),
              const SizedBox(height: 40),
              _buildInfoRow(context, 'Version', '1.0.0'),
              _buildInfoRow(context, 'Account', 'Webs'),
              const SizedBox(height: 24),
              Text(
                'Webs is designed around '
                'private communication, local-first '
                'data storage, and controlled sharing.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: WebsColors.textLight(context),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: WebsColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WebsColors.border(context), width: 2),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(color: WebsColors.textLight(context)),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: WebsColors.textDark(context),
            ),
          ),
        ],
      ),
    );
  }
}