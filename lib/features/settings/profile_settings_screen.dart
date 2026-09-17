import 'package:flutter/material.dart';

class ProfileSettingsScreen
    extends StatelessWidget {
  const ProfileSettingsScreen({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
        ),
      ),
      body: ListView(
        padding:
            const EdgeInsets.all(24),
        children: [
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor:
                  Colors.green.withValues(
                alpha: 0.12,
              ),
              child: const Text(
                'Y',
                style: TextStyle(
                  fontSize: 34,
                  color: Colors.green,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          const Center(
            child: Text(
              'Your Profile',
              style: TextStyle(
                fontSize: 24,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(
            height: 32,
          ),

          _buildInformationCard(
            context,
            icon:
                Icons.person_outline,
            title: 'Name',
            value:
                'Your name',
          ),

          const SizedBox(
            height: 12,
          ),

          _buildInformationCard(
            context,
            icon:
                Icons.email_outlined,
            title: 'Email',
            value:
                'Your verified email',
          ),

          const SizedBox(
            height: 12,
          ),

          _buildInformationCard(
            context,
            icon:
                Icons.phone_outlined,
            title: 'Phone number',
            value:
                'Your phone number',
          ),

          const SizedBox(
            height: 24,
          ),

          const Text(
            'Your email is your verification identity. '
            'Your phone number helps Webs People find you '
            'when another registered user has your number '
            'in their contacts.',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInformationCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(
          icon,
          color:
              Theme.of(context)
                  .colorScheme
                  .primary,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
        subtitle: Padding(
          padding:
              const EdgeInsets.only(
            top: 4,
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}