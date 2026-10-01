import 'package:flutter/material.dart';

import '/core/theme/webs_colors.dart';
import '/core/widgets/webs_background.dart';
import '../models/contact_match.dart';
import '../services/contact_matching_service.dart';

class ContactsTestScreen extends StatefulWidget {
  const ContactsTestScreen({super.key});

  @override
  State<ContactsTestScreen> createState() => _ContactsTestScreenState();
}

class _ContactsTestScreenState extends State<ContactsTestScreen> {
  final ContactMatchingService _matchingService = ContactMatchingService();

  List<ContactMatch> _matches = [];
  String _message = 'Press the button to find Webs users.';
  bool _loading = false;

  Future<void> _findUsers() async {
    setState(() {
      _loading = true;
      _message = 'Reading contacts...';
    });
    try {
      final matches = await _matchingService.findWebsPeople();
      setState(() {
        _matches = matches;
        _message = '${matches.length} Webs users found.';
      });
    } catch (e) {
      setState(() => _message = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Find People')),
      body: WebsBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: WebsColors.surface(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: WebsColors.border(context),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: WebsColors.softGreen(context),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.contacts_outlined,
                          color: WebsColors.primaryGreen,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Webs will check your phone contacts for registered Webs users.',
                          style: TextStyle(
                            color: WebsColors.textDark(context),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _loading ? null : _findUsers,
                  style: FilledButton.styleFrom(
                    backgroundColor: WebsColors.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _loading ? 'Searching...' : 'Find Webs Users',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _message,
                  style: TextStyle(
                    color: WebsColors.textLight(context),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: _matches.length,
                    itemBuilder: (context, index) {
                      final user = _matches[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: WebsColors.surface(context),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: WebsColors.shadow(context),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: WebsColors.border(context),
                            width: 2,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: WebsColors.softGreen(context),
                            child: const Icon(
                              Icons.person,
                              color: WebsColors.primaryGreen,
                            ),
                          ),
                          title: Text(
                            user.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: WebsColors.textDark(context),
                            ),
                          ),
                          subtitle: Text(
                            user.phoneNumber,
                            style: TextStyle(
                              color: WebsColors.textLight(context),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}