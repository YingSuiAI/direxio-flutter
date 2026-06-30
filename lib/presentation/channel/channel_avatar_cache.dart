import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';

typedef ChannelAvatarCacheReader = Future<Uint8List?> Function(String imageUrl);

const _channelAvatarMemoryCacheLimit = 1024;

ChannelAvatarCacheReader _channelAvatarCacheReader =
    _readCachedChannelAvatarBytes;
final _channelAvatarMemoryBytes = <String, Uint8List>{};
final _channelAvatarMemoryLoads = <String, Future<Uint8List?>>{};

@visibleForTesting
void setChannelAvatarCacheReaderForTesting(
  ChannelAvatarCacheReader? reader,
) {
  _channelAvatarCacheReader = reader ?? _readCachedChannelAvatarBytes;
}

@visibleForTesting
void clearChannelAvatarMemoryCacheForTesting() {
  _channelAvatarMemoryBytes.clear();
  _channelAvatarMemoryLoads.clear();
}

String? channelAvatarStableCacheKey({
  required String channelId,
  required String roomId,
}) {
  final id = channelId.trim();
  if (id.isNotEmpty) return 'channel:$id';
  final trimmedRoomId = roomId.trim();
  if (trimmedRoomId.isNotEmpty) return 'channel-room:$trimmedRoomId';
  return null;
}

Uint8List? cachedChannelAvatarBytes(String imageUrl, String? stableKey) {
  final memoryBytes = _channelAvatarMemoryBytes[imageUrl];
  if (memoryBytes != null && memoryBytes.isNotEmpty) {
    return memoryBytes;
  }
  if (stableKey == null) return null;
  final stableBytes = _channelAvatarMemoryBytes[stableKey];
  if (stableBytes != null && stableBytes.isNotEmpty) {
    return stableBytes;
  }
  return null;
}

Future<Uint8List?> loadCachedChannelAvatarBytes(
  String imageUrl, {
  required String? stableKey,
}) {
  final cachedBytes = cachedChannelAvatarBytes(imageUrl, stableKey);
  if (cachedBytes != null && cachedBytes.isNotEmpty) {
    return Future.value(cachedBytes);
  }

  final loadKey = _channelAvatarLoadKey(imageUrl, stableKey);
  final pending = _channelAvatarMemoryLoads[loadKey];
  if (pending != null) return pending;

  final load = _readCachedChannelAvatarBytesForKeys(
    imageUrl,
    stableKey: stableKey,
  ).then<Uint8List?>((bytes) {
    if (bytes == null || bytes.isEmpty) {
      return cachedChannelAvatarBytes(imageUrl, stableKey);
    }
    rememberChannelAvatarBytes(imageUrl, bytes);
    if (stableKey != null) {
      rememberChannelAvatarBytes(stableKey, bytes);
    }
    return bytes;
  }, onError: (_) {
    return cachedChannelAvatarBytes(imageUrl, stableKey);
  }).whenComplete(() {
    _channelAvatarMemoryLoads.remove(loadKey);
  });
  _channelAvatarMemoryLoads[loadKey] = load;
  return load;
}

Future<void> seedChannelAvatarCacheBytes(
  String imageUrl,
  Uint8List bytes, {
  String? stableKey,
  bool persist = true,
}) async {
  final trimmed = imageUrl.trim();
  if (trimmed.isEmpty || bytes.isEmpty) return;
  rememberChannelAvatarBytes(trimmed, bytes);
  if (stableKey != null && stableKey.trim().isNotEmpty) {
    rememberChannelAvatarBytes(stableKey.trim(), bytes);
  }
  if (!persist) return;
  try {
    await CachedNetworkImageProvider.defaultCacheManager.putFile(
      trimmed,
      bytes,
      fileExtension: _avatarFileExtension(trimmed),
    );
    final stableDiskKey = _channelAvatarStableDiskCacheKey(stableKey);
    if (stableDiskKey != null) {
      await CachedNetworkImageProvider.defaultCacheManager.putFile(
        trimmed,
        bytes,
        key: stableDiskKey,
        fileExtension: _avatarFileExtension(trimmed),
      );
    }
  } catch (_) {
    // Memory cache still keeps the freshly selected avatar visible.
  }
}

void rememberChannelAvatarBytes(String imageUrl, Uint8List bytes) {
  if (imageUrl.trim().isEmpty || bytes.isEmpty) return;
  _channelAvatarMemoryBytes.remove(imageUrl);
  _channelAvatarMemoryBytes[imageUrl] = bytes;
  while (_channelAvatarMemoryBytes.length > _channelAvatarMemoryCacheLimit) {
    _channelAvatarMemoryBytes.remove(_channelAvatarMemoryBytes.keys.first);
  }
}

Future<Uint8List?> _readCachedChannelAvatarBytes(String imageUrl) async {
  try {
    final cached = await CachedNetworkImageProvider.defaultCacheManager
        .getFileFromCache(imageUrl);
    final file = cached?.file;
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return bytes.isEmpty ? null : bytes;
  } catch (_) {
    return null;
  }
}

Future<Uint8List?> _readCachedChannelAvatarBytesForKeys(
  String imageUrl, {
  required String? stableKey,
}) async {
  final stableDiskKey = _channelAvatarStableDiskCacheKey(stableKey);
  if (stableDiskKey != null) {
    final stableBytes = await _channelAvatarCacheReader(stableDiskKey);
    if (stableBytes != null && stableBytes.isNotEmpty) {
      return stableBytes;
    }
  }
  return _channelAvatarCacheReader(imageUrl);
}

String _channelAvatarLoadKey(String imageUrl, String? stableKey) {
  final stableDiskKey = _channelAvatarStableDiskCacheKey(stableKey);
  if (stableDiskKey == null) return imageUrl;
  return '$imageUrl\n$stableDiskKey';
}

String? _channelAvatarStableDiskCacheKey(String? stableKey) {
  final trimmed = stableKey?.trim() ?? '';
  return trimmed.isEmpty ? null : 'channel-avatar:$trimmed';
}

String _avatarFileExtension(String imageUrl) {
  final path = Uri.tryParse(imageUrl)?.path.toLowerCase() ?? '';
  if (path.endsWith('.png')) return 'png';
  if (path.endsWith('.webp')) return 'webp';
  if (path.endsWith('.gif')) return 'gif';
  return 'jpg';
}
