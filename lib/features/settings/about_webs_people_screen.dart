import 'package:flutter/material.dart';

class AboutWebsPeopleScreen
    extends StatelessWidget {
  const AboutWebsPeopleScreen({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'About Webs People',
        ),
      ),
      body: ListView(
        padding:
            const EdgeInsets.all(24),
        children: [
          const SizedBox(
            height: 20,
          ),

          const CircleAvatar(
            radius: 48,
            backgroundColor:
                Colors.green,
            child: Icon(
              Icons.hub,
              color: Colors.white,
              size: 48,
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          const Text(
            'Webs People',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          const Text(
            'Connect privately with people you know.',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
            ),
          ),

          const SizedBox(
            height: 40,
          ),

          _buildInfoRow(
            'Version',
            '1.0.0',
          ),

          _buildInfoRow(
            'Account',
            'Webs People',
          ),

          const SizedBox(
            height: 24,
          ),

          const Text(
            'Webs People is designed around '
            'private communication, local-first '
            'data storage, and controlled sharing.',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String title,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 12,
      ),
      child: Row(
        children: [
          Text(
            title,
            style:
                const TextStyle(
              color: Colors.grey,
            ),
          ),

          const Spacer(),

          Text(
            value,
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}