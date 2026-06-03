import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

abstract class MediaThumbnailCache {
  Uint8List? peek(String key) => null;

  Future<Uint8List?> read(String key);

  Future<void> write(String key, List<int> bytes);

  Future<void> warm(Iterable<String> keys) async {
    for (final key in keys) {
      await read(key);
    }
  }
}

class DeferredMediaThumbnailCache implements MediaThumbnailCache {
  const DeferredMediaThumbnailCache(this._load);

  final Future<MediaThumbnailCache> Function() _load;

  @override
  Uint8List? peek(String key) => null;

  @override
  Future<Uint8List?> read(String key) async {
    return (await _load()).read(key);
  }

  @override
  Future<void> write(String key, List<int> bytes) async {
    await (await _load()).write(key, bytes);
  }

  @override
  Future<void> warm(Iterable<String> keys) async {
    await (await _load()).warm(keys);
  }
}

class MemoryBackedMediaThumbnailCache implements MediaThumbnailCache {
  MemoryBackedMediaThumbnailCache(
    this._storage, {
    this.maxMemoryEntries = 120,
  });

  final MediaThumbnailCache _storage;
  final int maxMemoryEntries;
  final Map<String, Uint8List> _memory = {};

  @override
  Uint8List? peek(String key) {
    final normalized = _normalizeKey(key);
    if (normalized.isEmpty) return null;
    final bytes = _memory.remove(normalized);
    if (bytes == null) return null;
    _memory[normalized] = bytes;
    return bytes;
  }

  @override
  Future<Uint8List?> read(String key) async {
    final normalized = _normalizeKey(key);
    if (normalized.isEmpty) return null;
    final warmed = peek(normalized);
    if (warmed != null) return warmed;
    final bytes = await _storage.read(normalized);
    if (bytes != null) _remember(normalized, bytes);
    return bytes;
  }

  @override
  Future<void> write(String key, List<int> bytes) async {
    final normalized = _normalizeKey(key);
    if (normalized.isEmpty || bytes.isEmpty) return;
    final stored = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    _remember(normalized, stored);
    await _storage.write(normalized, stored);
  }

  @override
  Future<void> warm(Iterable<String> keys) async {
    final unique = <String>{
      for (final key in keys.map(_normalizeKey))
        if (key.isNotEmpty) key,
    };
    for (final key in unique) {
      await read(key);
    }
  }

  void _remember(String key, Uint8List bytes) {
    _memory.remove(key);
    _memory[key] = bytes;
    while (_memory.length > maxMemoryEntries) {
      _memory.remove(_memory.keys.first);
    }
  }
}

class FileMediaThumbnailCache implements MediaThumbnailCache {
  const FileMediaThumbnailCache(
    this.directory, {
    this.maxBytes = 5 * 1024 * 1024,
  });

  final Directory directory;
  final int maxBytes;

  @override
  Uint8List? peek(String key) => null;

  @override
  Future<Uint8List?> read(String key) async {
    final file = _fileForKey(key);
    if (file == null || !await file.exists()) return null;
    try {
      final length = await file.length();
      if (length <= 0 || length > maxBytes) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, List<int> bytes) async {
    final file = _fileForKey(key);
    if (file == null || bytes.isEmpty || bytes.length > maxBytes) return;
    await directory.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<void> warm(Iterable<String> keys) async {
    for (final key in keys) {
      await read(key);
    }
  }

  File? _fileForKey(String key) {
    final normalized = key.trim();
    if (normalized.isEmpty) return null;
    final encoded = base64Url.encode(utf8.encode(normalized));
    return File('${directory.path}/$encoded.thumb');
  }
}

String _normalizeKey(String key) => key.trim();
