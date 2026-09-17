import 'package:flutter/material.dart';

import '../models/contact_match.dart';
import '../services/contact_matching_service.dart';

class ContactsTestScreen
    extends StatefulWidget {
  const ContactsTestScreen({
    super.key,
  });

  @override
  State<ContactsTestScreen> createState() =>
      _ContactsTestScreenState();
}

class _ContactsTestScreenState
    extends State<ContactsTestScreen> {
  final ContactMatchingService
      _matchingService =
      ContactMatchingService();

  List<ContactMatch> _matches = [];

  String _message =
      'Press the button to find Webs users.';

  bool _loading = false;

  Future<void> _findUsers() async {
    setState(() {
      _loading = true;
      _message =
          'Reading contacts...';
    });

    try {
      final matches =
          await _matchingService
              .findWebsPeople();

      setState(() {
        _matches = matches;

        _message =
            '${matches.length} Webs users found.';
      });
    } catch (e) {
      setState(() {
        _message = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Find People'),
      ),
      body: Padding(
        padding:
            const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Webs will check your phone contacts for registered Webs users.',
            ),

            const SizedBox(
              height: 20,
            ),

            ElevatedButton(
              onPressed:
                  _loading
                      ? null
                      : _findUsers,
              child: Text(
                _loading
                    ? 'Searching...'
                    : 'Find Webs Users',
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            Text(_message),

            const SizedBox(
              height: 10,
            ),

            Expanded(
              child: ListView.builder(
                itemCount:
                    _matches.length,
                itemBuilder:
                    (context, index) {
                  final user =
                      _matches[index];

                  return ListTile(
                    title:
                        Text(user.name),
                    subtitle:
                        Text(
                      user.phoneNumber,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}