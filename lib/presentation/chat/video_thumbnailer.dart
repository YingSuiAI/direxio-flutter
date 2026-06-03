import 'package:flutter/services.dart';

const _videoToolsChannel = MethodChannel('p2p_im/video_tools');

class ChatVideoThumbnail {
  const ChatVideoThumbnail({
    required this.bytes,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.durationMs,
  });

  final Uint8List bytes;
  final String mimeType;
  final int width;
  final int height;
  final int durationMs;
}

Future<ChatVideoThumbnail?> createChatVideoThumbnail(String path) async {
  final trimmedPath = path.trim();
  if (trimmedPath.isEmpty) return null;
  try {
    final result = await _videoToolsChannel.invokeMapMethod<String, dynamic>(
      'createThumbnail',
      {'path': trimmedPath},
    );
    if (result == null) return null;
    final bytes = result['bytes'];
    if (bytes is! Uint8List || bytes.isEmpty) return null;
    return ChatVideoThumbnail(
      bytes: bytes,
      mimeType: (result['mimeType'] as String?)?.trim().isNotEmpty == true
          ? result['mimeType'] as String
          : 'image/jpeg',
      width: _intValue(result['width']),
      height: _intValue(result['height']),
      durationMs: _intValue(result['durationMs']),
    );
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
}

int _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}
