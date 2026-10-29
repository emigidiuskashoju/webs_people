import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/network/api_endpoints.dart';
import '../../../core/theme/webs_colors.dart';

class OwnerAnnouncementDialog extends StatefulWidget {
  const OwnerAnnouncementDialog({super.key});

  @override
  State<OwnerAnnouncementDialog> createState() => _OwnerAnnouncementDialogState();
}

class _OwnerAnnouncementDialogState extends State<OwnerAnnouncementDialog> {
  @override
  void initState() {
    super.initState();
    _checkForAnnouncements();
  }

  Future<void> _checkForAnnouncements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seenId = prefs.getInt('last_seen_announcement_id') ?? 0;

      final response = await http.get(
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.announcementsLatest}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == 'success') {
          final ann = data['data'];
          final newId = ann['id'];

          // If it's a new announcement the user hasn't seen yet
          if (newId > seenId) {
            if (!mounted) return;
            _showWhatsAppStyleDialog(
              context,
              title: ann['title'] ?? 'Webs Update',
              body: ann['body'] ?? '',
              imageUrl: ann['image_url'],
              onDismiss: () async {
                // Save so it doesn't show again
                await prefs.setInt('last_seen_announcement_id', newId);
              },
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Announcement check failed: $e');
    }
  }

  void _showWhatsAppStyleDialog(
    BuildContext context, {
    required String title,
    required String body,
    String? imageUrl,
    required VoidCallback onDismiss,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Logo + Name + Verified Tick
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/images/app_logo.png', // Your logo
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        // Fallback if image fails to load
                        errorBuilder: (_, __, ___) => Container(
                          width: 40, height: 40, color: Colors.green,
                          child: const Icon(Icons.public, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Webs',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            title, // Show the title from admin
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // The WhatsApp Blue Tick
                    const Icon(Icons.verified, color: Color(0xFF25D366), size: 20),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Image Attachment (if any)
                if (imageUrl != null && imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                
                if (imageUrl != null && imageUrl.isNotEmpty)
                  const SizedBox(height: 16),

                // Text Body
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Close Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onDismiss();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: WebsColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text('Got it', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); // It's an invisible widget that triggers on mount
  }
}