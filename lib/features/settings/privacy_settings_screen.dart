import 'package:flutter/material.dart';

class PrivacySettingsScreen
    extends StatelessWidget {
  const PrivacySettingsScreen({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Privacy',
        ),
      ),
      body: ListView(
        padding:
            const EdgeInsets.all(24),
        children: [
          const Icon(
            Icons.lock_outline,
            size: 72,
            color: Colors.green,
          ),

          const SizedBox(
            height: 20,
          ),

          const Text(
            'Your privacy matters',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          const Text(
            'Webs People is designed to keep '
            'as much information as possible '
            'on your phone instead of permanently '
            'storing unnecessary data on the server.',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              height: 1.5,
            ),
          ),

          const SizedBox(
            height: 32,
          ),

          _buildPrivacyItem(
            icon:
                Icons.storage_outlined,
            title:
                'Local-first data',
            description:
                'Information that does not need to '
                'be stored on the server should remain '
                'on your device.',
          ),

          _buildPrivacyItem(
            icon:
                Icons.contacts_outlined,
            title:
                'Contacts',
            description:
                'Webs People should not permanently '
                'store your entire phone address book.',
          ),

          _buildPrivacyItem(
            icon:
                Icons.location_on_outlined,
            title:
                'Location',
            description:
                'Location sharing is controlled by '
                'you and should only be active when '
                'you choose to share it.',
          ),

          _buildPrivacyItem(
            icon:
                Icons.chat_outlined,
            title:
                'Messages',
            description:
                'Messages are designed around local-first '
                'storage with the server used for temporary '
                'delivery when necessary.',
          ),

          _buildPrivacyItem(
            icon:
                Icons.call_outlined,
            title:
                'Call history',
            description:
                'Call history is intended to remain '
                'on your device rather than becoming '
                'a permanent server-side history.',
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 24,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Colors.green,
          ),

          const SizedBox(
            width: 16,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  description,
                  style:
                      const TextStyle(
                    color: Colors.grey,
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