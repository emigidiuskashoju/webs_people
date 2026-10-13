import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// A disk-backed cache for profile photos.
///
/// Every profile photo URL is downloaded once and stored in
/// the app's cache directory. Subsequent displays load from
/// disk instantly — no network round-trip, no spinner.
///
/// When a user uploads a new photo, call [evict] with the URL
/// of the *old* photo (if any) and the cache will drop it so
/// all screens fetch the fresh version.
class ProfilePhotoCache {
  ProfilePhotoCache._();
  static final ProfilePhotoCache instance = ProfilePhotoCache._();

  static const String _subDir = 'profile_photos';

  Directory? _cacheDir;
  final Map<String, File> _memoryCache = {};

  /// In-flight downloads so we don't fetch the same URL twice.
  final Map<String, Future<File?>> _pending = {};

  Future<Directory> _getCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;

    final base = await getApplicationCacheDirectory();
    final dir = Directory('${base.path}/$_subDir');

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    _cacheDir = dir;
    return dir;
  }

  /// Returns a stable filename for a URL, so the same URL
  /// always maps to the same cached file.
  String _filenameFor(String url) {
    final bytes = url.codeUnits;
    final digest = md5.convert(bytes).toString();
    return '$digest.img';
  }

  /// Returns a cached file for [url], or null if not cached.
  ///
  /// If the file is missing but the URL is valid, it will kick
  /// off a background download so the next call finds it.
  Future<File?> get(String? url) async {
    if (url == null || url.trim().isEmpty) return null;

    // Memory cache is the fastest path.
    final memHit = _memoryCache[url];
    if (memHit != null && await memHit.exists()) {
      return memHit;
    }

    final dir = await _getCacheDir();
    final file = File('${dir.path}/${_filenameFor(url)}');

    if (await file.exists()) {
      _memoryCache[url] = file;
      return file;
    }

    // Not cached yet — download in the background.
    // The caller can use the fallback initial in the meantime.
    unawaited(download(url));
    return null;
  }

  /// Downloads [url] and stores it in the local cache.
  ///
  /// Safe to call multiple times — concurrent calls for the
  /// same URL share one network request.
  Future<File?> download(String url) async {
    if (url.trim().isEmpty) return null;

    // Deduplicate concurrent downloads.
    final existing = _pending[url];
    if (existing != null) return existing;

    final future = _doDownload(url);
    _pending[url] = future;

    try {
      return await future;
    } finally {
      _pending.remove(url);
    }
  }

  Future<File?> _doDownload(String url) async {
    try {
      final dir = await _getCacheDir();
      final file = File('${dir.path}/${_filenameFor(url)}');

      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode != 200) {
        debugPrint('CACHE: photo download failed (${response.statusCode})');
        return null;
      }

      await file.writeAsBytes(response.bodyBytes, flush: true);
      _memoryCache[url] = file;

      debugPrint('CACHE: photo cached at ${file.path}');
      return file;
    } catch (e) {
      debugPrint('CACHE: photo download error: $e');
      return null;
    }
  }

  /// Removes a specific URL from the cache.
  ///
  /// Call this when a user updates their profile photo and the
  /// old URL is no longer valid — otherwise screens that still
  /// have the old URL loaded would keep showing the old image.
  Future<void> evict(String? url) async {
    if (url == null || url.trim().isEmpty) return;

    _memoryCache.remove(url);

    try {
      final dir = await _getCacheDir();
      final file = File('${dir.path}/${_filenameFor(url)}');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('CACHE: evict failed: $e');
    }
  }

  /// Clears every cached profile photo.
  ///
  /// Call on logout so no photos leak between accounts.
  Future<void> clear() async {
    _memoryCache.clear();

    try {
      final dir = await _getCacheDir();
      if (await dir.exists()) {
        final files = dir.listSync();
        for (final f in files) {
          if (f is File) {
            try {
              await f.delete();
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('CACHE: clear failed: $e');
    }
  }
}