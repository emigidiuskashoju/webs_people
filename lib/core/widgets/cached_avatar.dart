import 'dart:io';

import 'package:flutter/material.dart';

import '../cache/profile_photo_cache.dart';
import '../theme/webs_colors.dart';

/// A circular avatar that caches profile photos on disk.
///
/// Behavior:
///   1. If [photoUrl] is null/empty → show [fallbackInitial]
///   2. If the photo is cached → show the cached file instantly
///   3. If not cached → show [fallbackInitial] and download
///      in the background. The next build (typically after a
///      setState or screen rebuild) will show the photo.
///
/// This never shows a loading spinner.
class CachedAvatar extends StatefulWidget {
  final String? photoUrl;
  final String fallbackInitial;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const CachedAvatar({
    super.key,
    required this.photoUrl,
    required this.fallbackInitial,
    this.radius = 20,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  State<CachedAvatar> createState() => _CachedAvatarState();
}

class _CachedAvatarState extends State<CachedAvatar> {
  File? _cachedFile;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(CachedAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl) {
      _cachedFile = null;
      _resolved = false;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final url = widget.photoUrl;
    if (url == null || url.trim().isEmpty) {
      if (mounted) setState(() => _resolved = true);
      return;
    }

    final file = await ProfilePhotoCache.instance.get(url);

    if (!mounted) return;

    setState(() {
      _cachedFile = file;
      _resolved = true;
    });

    // If not cached yet, download and rebuild once it's ready.
    if (file == null) {
      final downloaded =
          await ProfilePhotoCache.instance.download(url);
      if (!mounted) return;
      if (downloaded != null) {
        setState(() => _cachedFile = downloaded);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.backgroundColor ?? WebsColors.softGreen(context);
    final fg = widget.foregroundColor ?? WebsColors.primaryGreen;

    if (_cachedFile != null && _cachedFile!.existsSync()) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: bg,
        backgroundImage: FileImage(_cachedFile!),
      );
    }

    // Fallback initial — shown while loading or if no photo.
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: bg,
      child: Text(
        widget.fallbackInitial.isNotEmpty
            ? widget.fallbackInitial[0].toUpperCase()
            : '?',
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.bold,
          fontSize: widget.radius * 0.9,
        ),
      ),
    );
  }
}