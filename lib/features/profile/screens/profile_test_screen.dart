import 'package:flutter/material.dart';

import '../../auth/models/user_model.dart';
import '/core/theme/webs_colors.dart';
import '/core/widgets/webs_background.dart';
import '../models/local_profile.dart';
import '../services/profile_service.dart';

class ProfileTestScreen extends StatefulWidget {
  final UserModel user;

  const ProfileTestScreen({
    super.key,
    required this.user,
  });

  @override
  State<ProfileTestScreen> createState() => _ProfileTestScreenState();
}

class _ProfileTestScreenState extends State<ProfileTestScreen> {
  final ProfileService _profileService = ProfileService();
  final TextEditingController _aboutController = TextEditingController();

  LocalProfile? _profile;
  String _message = 'No local profile loaded.';
  bool _loading = false;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = 'Loading local profile...';
    });
    try {
      final profile = await _profileService.getProfile(widget.user.id);
      setState(() {
        _profile = profile;
        _aboutController.text = profile?.about ?? '';
        _message = profile == null
            ? 'No local profile exists.'
            : 'Local profile loaded.';
      });
    } catch (e) {
      setState(() => _message = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _loading = true;
      _message = 'Saving profile locally...';
    });
    try {
      final profile = await _profileService.saveProfile(
        userId: widget.user.id,
        about: _aboutController.text.trim(),
      );
      setState(() {
        _profile = profile;
        _message = 'Profile saved to this phone.';
      });
    } catch (e) {
      setState(() => _message = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    setState(() {
      _loading = true;
      _message = 'Deleting local profile...';
    });
    try {
      await _profileService.deleteProfile(widget.user.id);
      setState(() {
        _profile = null;
        _aboutController.clear();
        _message = 'Local profile deleted.';
      });
    } catch (e) {
      setState(() => _message = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _aboutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Local Profile')),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User: ${widget.user.name}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: WebsColors.textDark(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Phone: ${widget.user.phoneNumber}',
                        style: TextStyle(
                          color: WebsColors.textLight(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _aboutController,
                  maxLines: 4,
                  style: TextStyle(color: WebsColors.textDark(context)),
                  decoration: InputDecoration(
                    labelText: 'About',
                    labelStyle:
                        TextStyle(color: WebsColors.textLight(context)),
                    filled: true,
                    fillColor: WebsColors.softGreen(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: WebsColors.primaryGreen,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _loading ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: WebsColors.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Save Locally',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _loading ? null : _load,
                  style: FilledButton.styleFrom(
                    backgroundColor: WebsColors.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Load From Local Database',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _loading ? null : _delete,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Delete Local Profile',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: WebsColors.softGreen(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _message,
                    style: TextStyle(color: WebsColors.textDark(context)),
                  ),
                ),
                if (_profile != null) ...[
                  const SizedBox(height: 15),
                  Text(
                    'Updated: ${_profile!.updatedAt}',
                    style: TextStyle(color: WebsColors.textLight(context)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}