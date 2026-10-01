import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/webs_colors.dart';
import '../../core/widgets/webs_background.dart';
import 'services/profile_service.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final ProfileService _profileService = ProfileService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();

  bool _isLoading = true;
  bool _isSavingName = false;
  bool _isUploadingPhoto = false;
  bool _isRemovingPhoto = false;

  String _email = '';
  String _phone = '';
  String? _profilePhotoUrl;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final user = await _profileService.getProfile();
      if (!mounted) return;
      setState(() {
        _nameController.text = _stringValue(user['name']);
        _email = _stringValue(user['email']);
        _phone = _stringValue(user['phone']);
        _profilePhotoUrl = _nullableString(user['profile_photo_url']);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = _cleanError(e);
      });
    }
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('Name cannot be empty.');
      return;
    }
    if (name.length < 2) {
      _showMessage('Name must contain at least 2 characters.');
      return;
    }
    setState(() => _isSavingName = true);
    try {
      final user = await _profileService.updateName(name);
      if (!mounted) return;
      setState(() {
        _nameController.text = _stringValue(user['name']);
        _profilePhotoUrl = _nullableString(user['profile_photo_url']);
      });
      _showMessage('Name updated successfully.');
    } catch (e) {
      if (!mounted) return;
      _showMessage(_cleanError(e));
    } finally {
      if (mounted) setState(() => _isSavingName = false);
    }
  }

  Future<void> _pickPhoto() async {
    if (_isUploadingPhoto || _isRemovingPhoto) return;
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (image == null) return;
      final file = File(image.path);
      await _uploadPhoto(file);
    } catch (e) {
      if (!mounted) return;
      _showMessage(_cleanError(e));
    }
  }

  Future<void> _uploadPhoto(File file) async {
    setState(() => _isUploadingPhoto = true);
    try {
      final user = await _profileService.uploadPhoto(file);
      if (!mounted) return;
      setState(() {
        _profilePhotoUrl = _nullableString(user['profile_photo_url']);
      });
      _showMessage('Profile photo updated successfully.');
    } catch (e) {
      if (!mounted) return;
      _showMessage(_cleanError(e));
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _removePhoto() async {
    if (_isUploadingPhoto || _isRemovingPhoto) return;
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove profile photo?'),
          content: const Text(
            'Your profile will return to the default letter avatar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: WebsColors.primaryGreen,
              ),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
    if (shouldRemove != true) return;
    setState(() => _isRemovingPhoto = true);
    try {
      final user = await _profileService.removePhoto();
      if (!mounted) return;
      setState(() {
        _profilePhotoUrl = _nullableString(user['profile_photo_url']);
      });
      _showMessage('Profile photo removed.');
    } catch (e) {
      if (!mounted) return;
      _showMessage(_cleanError(e));
    } finally {
      if (mounted) setState(() => _isRemovingPhoto = false);
    }
  }

  Widget _buildAvatar() {
    final photoUrl = _profilePhotoUrl;
    if (photoUrl != null && photoUrl.trim().isNotEmpty) {
      return CircleAvatar(
        radius: 52,
        backgroundColor: WebsColors.softGreen(context),
        backgroundImage: NetworkImage(photoUrl),
      );
    }
    final initial = _getInitial();
    return CircleAvatar(
      radius: 52,
      backgroundColor: WebsColors.softGreen(context),
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.bold,
          color: WebsColors.primaryGreen,
        ),
      ),
    );
  }

  String _getInitial() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return 'W';
    return name.substring(0, 1).toUpperCase();
  }

  Widget _buildPhotoActions() {
    final hasPhoto =
        _profilePhotoUrl != null && _profilePhotoUrl!.trim().isNotEmpty;
    if (_isUploadingPhoto || _isRemovingPhoto) {
      return const Padding(
        padding: EdgeInsets.only(top: 14),
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: WebsColors.primaryGreen,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: _pickPhoto,
            icon: const Icon(
              Icons.photo_camera_outlined,
              color: WebsColors.primaryGreen,
            ),
            label: Text(
              hasPhoto ? 'Change photo' : 'Add photo',
              style: const TextStyle(color: WebsColors.primaryGreen),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: WebsColors.primaryGreen),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          if (hasPhoto) ...[
            const SizedBox(width: 10),
            TextButton(
              onPressed: _removePhoto,
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent,
              ),
              child: const Text('Remove'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return TextField(
      controller: TextEditingController(text: value),
      readOnly: true,
      enabled: false,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: WebsColors.textLight(context)),
        prefixIcon: Icon(icon, color: WebsColors.primaryGreen),
        suffixIcon: Icon(
          Icons.lock_outline,
          size: 18,
          color: WebsColors.textLight(context),
        ),
        filled: true,
        fillColor: WebsColors.softGreen(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  String _stringValue(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  String? _nullableString(dynamic value) {
    final text = _stringValue(value);
    if (text.isEmpty) return null;
    return text;
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('ApiException: ', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Profile')),
      body: WebsBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: WebsColors.primaryGreen,
                  ),
                )
              : RefreshIndicator(
                  color: WebsColors.primaryGreen,
                  onRefresh: _loadProfile,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 100, 20, 30),
                    children: [
                      Center(child: _buildAvatar()),
                      _buildPhotoActions(),
                      const SizedBox(height: 28),
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      Text(
                        'Name',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: WebsColors.textDark(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        style: TextStyle(color: WebsColors.textDark(context)),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.person_outline,
                            color: WebsColors.primaryGreen,
                          ),
                          hintText: 'Your name',
                          hintStyle:
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
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: _isSavingName ? null : _saveName,
                          style: FilledButton.styleFrom(
                            backgroundColor: WebsColors.primaryGreen,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isSavingName
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Save Name',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Account information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: WebsColors.textDark(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Email and phone number were provided during registration and cannot be changed here.',
                        style: TextStyle(
                          fontSize: 12,
                          color: WebsColors.textLight(context),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildReadOnlyField(
                        label: 'Email',
                        value: _email.isEmpty ? 'Not provided' : _email,
                        icon: Icons.email_outlined,
                      ),
                      const SizedBox(height: 16),
                      _buildReadOnlyField(
                        label: 'Phone number',
                        value: _phone.isEmpty ? 'Not provided' : _phone,
                        icon: Icons.phone_outlined,
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: WebsColors.softGreen(context),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: WebsColors.primaryGreen,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Only your name and profile photo can be changed. Changes are saved to the Webs server so your updated profile can be used by other Webs features.',
                                style: TextStyle(
                                  color: WebsColors.textDark(context),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
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