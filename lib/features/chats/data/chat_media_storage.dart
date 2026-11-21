import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Stores chat images and voice notes on this phone.
///
/// Media is relayed through the server only until the recipient
/// downloads it; the lasting copy lives here, next to the local chat
/// database, the same way text messages do.
class ChatMediaStorage {
  ChatMediaStorage._();
  static final ChatMediaStorage instance = ChatMediaStorage._();

  Directory? _dir;

  Future<Directory> _mediaDir() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/chat_media');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _dir = dir;
    return dir;
  }

  String _extensionFor(String type, String? mime) {
    if (type == 'audio') return 'm4a';
    if (mime != null) {
      if (mime.contains('png')) return 'png';
      if (mime.contains('webp')) return 'webp';
      if (mime.contains('gif')) return 'gif';
    }
    return 'jpg';
  }

  /// Saves downloaded bytes and returns the local file path.
  Future<String> saveBytes({
    required String id,
    required Uint8List bytes,
    required String type,
    String? mime,
  }) async {
    final dir = await _mediaDir();
    final file = File('${dir.path}/$id.${_extensionFor(type, mime)}');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// A fresh file path for a voice note about to be recorded.
  Future<String> newAudioPath(String id) async {
    final dir = await _mediaDir();
    return '${dir.path}/$id.m4a';
  }

  Future<void> deleteIfExists(String? path) async {
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
