import 'package:flutter/material.dart';

import '../../core/theme/webs_colors.dart';
import '../../core/widgets/webs_background.dart';

class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Privacy')),
      body: WebsBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: WebsColors.softGreen(context),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    size: 64,
                    color: WebsColors.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Your privacy matters',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: WebsColors.textDark(context),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Webs is designed to keep '
                'as much information as possible '
                'on your phone instead of permanently '
                'storing unnecessary data on the server.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: WebsColors.textLight(context),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              _buildItem(
                context,
                icon: Icons.storage_outlined,
                title: 'Local-first data',
                description:
                    'Information that does not need to '
                    'be stored on the server should remain '
                    'on your device.',
              ),
              _buildItem(
                context,
                icon: Icons.contacts_outlined,
                title: 'Contacts',
                description:
                    'Webs should not permanently '
                    'store your entire phone address book.',
              ),
              _buildItem(
                context,
                icon: Icons.location_on_outlined,
                title: 'Location',
                description:
                    'Location sharing is controlled by '
                    'you and should only be active when '
                    'you choose to share it.',
              ),
              _buildItem(
                context,
                icon: Icons.chat_outlined,
                title: 'Messages',
                description:
                    'Messages are designed around local-first '
                    'storage with the server used for temporary '
                    'delivery when necessary.',
              ),
              _buildItem(
                context,
                icon: Icons.call_outlined,
                title: 'Call history',
                description:
                    'Call history is intended to remain '
                    'on your device rather than becoming '
                    'a permanent server-side history.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WebsColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WebsColors.border(context), width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: WebsColors.softGreen(context),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: WebsColors.primaryGreen, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: WebsColors.textDark(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: WebsColors.textLight(context),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}