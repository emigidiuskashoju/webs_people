import 'package:flutter/material.dart';

import '../../auth/models/user_model.dart';
import '../models/local_profile.dart';
import '../services/profile_service.dart';

class ProfileTestScreen
    extends StatefulWidget {
  final UserModel user;

  const ProfileTestScreen({
    super.key,
    required this.user,
  });

  @override
  State<ProfileTestScreen> createState() =>
      _ProfileTestScreenState();
}

class _ProfileTestScreenState
    extends State<ProfileTestScreen> {
  final ProfileService _profileService =
      ProfileService();

  final TextEditingController
      _aboutController =
      TextEditingController();

  LocalProfile? _profile;

  String _message =
      'No local profile loaded.';

  bool _loading = false;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message =
          'Loading local profile...';
    });

    try {
      final profile =
          await _profileService
              .getProfile(
        widget.user.id,
      );

      setState(() {
        _profile = profile;

        _aboutController.text =
            profile?.about ?? '';

        _message =
            profile == null
                ? 'No local profile exists.'
                : 'Local profile loaded.';
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

  Future<void> _save() async {
    setState(() {
      _loading = true;
      _message =
          'Saving profile locally...';
    });

    try {
      final profile =
          await _profileService
              .saveProfile(
        userId: widget.user.id,
        about:
            _aboutController.text
                .trim(),
      );

      setState(() {
        _profile = profile;

        _message =
            'Profile saved to this phone.';
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

  Future<void> _delete() async {
    setState(() {
      _loading = true;
      _message =
          'Deleting local profile...';
    });

    try {
      await _profileService
          .deleteProfile(
        widget.user.id,
      );

      setState(() {
        _profile = null;
        _aboutController.clear();

        _message =
            'Local profile deleted.';
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
  void dispose() {
    _aboutController.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Local Profile'),
      ),
      body: Padding(
        padding:
            const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            Text(
              'User: ${widget.user.name}',
            ),

            Text(
              'Phone: ${widget.user.phoneNumber}',
            ),

            const SizedBox(
              height: 20,
            ),

            TextField(
              controller:
                  _aboutController,
              maxLines: 4,
              decoration:
                  const InputDecoration(
                labelText: 'About',
                border:
                    OutlineInputBorder(),
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            ElevatedButton(
              onPressed:
                  _loading
                      ? null
                      : _save,
              child: const Text(
                'Save Locally',
              ),
            ),

            ElevatedButton(
              onPressed:
                  _loading
                      ? null
                      : _load,
              child: const Text(
                'Load From Local Database',
              ),
            ),

            ElevatedButton(
              onPressed:
                  _loading
                      ? null
                      : _delete,
              child: const Text(
                'Delete Local Profile',
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            Text(_message),

            if (_profile != null) ...[
              const SizedBox(
                height: 15,
              ),
              Text(
                'Updated: ${_profile!.updatedAt}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}