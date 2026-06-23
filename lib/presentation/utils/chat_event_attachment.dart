import 'package:matrix/matrix.dart';

Future<MatrixFile> downloadChatEventThumbnail(Event event) async {
  if (_isImageMessage(event)) return downloadChatEventAttachment(event);

  final normalized = _normalizedThumbnailEvent(event);
  if (_isVideoMessage(event) && !_hasUsableVideoThumbnail(event, normalized)) {
    throw "This video event hasn't a usable image thumbnail.";
  }
  if (!_hasMatrixThumbnail(event) && normalized != null) {
    try {
      return await normalized.downloadAndDecryptAttachment(getThumbnail: true);
    } catch (_) {
      rethrow;
    }
  }
  try {
    return await event.downloadAndDecryptAttachment(getThumbnail: true);
  } catch (_) {
    if (normalized == null) rethrow;
    return normalized.downloadAndDecryptAttachment(getThumbnail: true);
  }
}

Future<MatrixFile> downloadChatEventAttachment(Event event) async {
  if (event.hasAttachment) {
    try {
      return await event.downloadAndDecryptAttachment();
    } catch (_) {
      final normalized = _normalizedAttachmentEvent(event);
      if (normalized == null) rethrow;
      return normalized.downloadAndDecryptAttachment();
    }
  }

  final normalized = _normalizedAttachmentEvent(event);
  if (normalized == null) {
    throw "This event hasn't any attachment or thumbnail.";
  }
  return normalized.downloadAndDecryptAttachment();
}

Event? _normalizedThumbnailEvent(Event event) {
  final content = Map<String, dynamic>.from(event.content);
  final info = Map<String, dynamic>.from(
    content['info'] is Map ? content['info'] as Map : const <String, dynamic>{},
  );
  final thumbnailUrl = _firstString([
    info['thumbnail_url'],
    info['thumbnailUrl'],
    info['thumbnail_mxc_url'],
    info['thumbnailMxcUrl'],
    content['thumbnail_url'],
    content['thumbnailUrl'],
    content['thumbnail_mxc_url'],
    content['thumbnailMxcUrl'],
  ]);
  final thumbnailFile = _firstMap([
    info['thumbnail_file'],
    info['thumbnailFile'],
    content['thumbnail_file'],
    content['thumbnailFile'],
  ]);
  if (thumbnailUrl == null && thumbnailFile == null) return null;

  final thumbnailInfo = Map<String, dynamic>.from(
    info['thumbnail_info'] is Map
        ? info['thumbnail_info'] as Map
        : content['thumbnail_info'] is Map
            ? content['thumbnail_info'] as Map
            : const <String, dynamic>{},
  );
  final thumbnailMimeType = _firstString([
    thumbnailInfo['mimetype'],
    info['thumbnail_mimetype'],
    info['thumbnail_mime_type'],
    info['thumbnailMimeType'],
    content['thumbnail_mimetype'],
    content['thumbnail_mime_type'],
    content['thumbnailMimeType'],
    thumbnailFile?['mimetype'],
    thumbnailFile?['mime_type'],
    thumbnailFile?['mimeType'],
  ]);
  final thumbnailSize = _firstInt([
    thumbnailInfo['size'],
    info['thumbnail_size'],
    info['thumbnailSize'],
    content['thumbnail_size'],
    content['thumbnailSize'],
    thumbnailFile?['size'],
  ]);
  final thumbnailWidth = _firstInt([
    thumbnailInfo['w'],
    thumbnailInfo['width'],
    info['thumbnail_width'],
    info['thumbnailWidth'],
    content['thumbnail_width'],
    content['thumbnailWidth'],
  ]);
  final thumbnailHeight = _firstInt([
    thumbnailInfo['h'],
    thumbnailInfo['height'],
    info['thumbnail_height'],
    info['thumbnailHeight'],
    content['thumbnail_height'],
    content['thumbnailHeight'],
  ]);

  if (thumbnailUrl != null) info['thumbnail_url'] = thumbnailUrl;
  if (thumbnailFile != null) info['thumbnail_file'] = thumbnailFile;
  if (thumbnailMimeType != null) thumbnailInfo['mimetype'] = thumbnailMimeType;
  if (thumbnailSize != null) thumbnailInfo['size'] = thumbnailSize;
  if (thumbnailWidth != null) thumbnailInfo['w'] = thumbnailWidth;
  if (thumbnailHeight != null) thumbnailInfo['h'] = thumbnailHeight;
  if (thumbnailInfo.isNotEmpty) info['thumbnail_info'] = thumbnailInfo;
  content['info'] = info;

  return _eventWithContent(event, content);
}

bool _hasMatrixThumbnail(Event event) {
  final info = event.content['info'];
  if (info is! Map) return false;
  return _firstString([info['thumbnail_url']]) != null ||
      _firstMap([info['thumbnail_file']]) != null;
}

bool _hasUsableVideoThumbnail(Event event, Event? normalized) {
  final target = normalized ?? event;
  final content = target.content;
  final info = content['info'];
  if (info is! Map) return false;
  final thumbnailUrl = _firstString([info['thumbnail_url']]);
  final thumbnailFile = _firstMap([info['thumbnail_file']]);
  if (thumbnailUrl == null && thumbnailFile == null) return false;

  final mediaUrl = _firstString([content['url'], info['url']]);
  if (thumbnailUrl != null && mediaUrl != null && thumbnailUrl == mediaUrl) {
    return false;
  }

  final thumbnailInfo = info['thumbnail_info'];
  final thumbnailMimeType = _firstString([
    if (thumbnailInfo is Map) thumbnailInfo['mimetype'],
    thumbnailFile?['mimetype'],
    thumbnailFile?['mime_type'],
    thumbnailFile?['mimeType'],
  ]);
  return thumbnailMimeType == null ||
      thumbnailMimeType.toLowerCase().startsWith('image/');
}

bool _isVideoMessage(Event event) {
  return _firstString([event.content['msgtype']]) == MessageTypes.Video;
}

bool _isImageMessage(Event event) {
  return _firstString([event.content['msgtype']]) == MessageTypes.Image;
}

Event? _normalizedAttachmentEvent(Event event) {
  final content = Map<String, dynamic>.from(event.content);
  final info = Map<String, dynamic>.from(
    content['info'] is Map ? content['info'] as Map : const <String, dynamic>{},
  );
  final url = _firstString([
    content['url'],
    content['media_url'],
    content['mediaUrl'],
    content['mxc_url'],
    content['mxcUrl'],
    content['org.matrix.msc1767.url'],
    info['url'],
    info['media_url'],
    info['mediaUrl'],
    info['mxc_url'],
    info['mxcUrl'],
    info['org.matrix.msc1767.url'],
  ]);
  final file = _firstMap([
    content['file'],
    content['org.matrix.msc1767.file'],
    info['file'],
    info['org.matrix.msc1767.file'],
  ]);
  if (url == null && file == null) return null;

  final mimeType = _firstString([
    info['mimetype'],
    info['mime_type'],
    info['mimeType'],
    content['mimetype'],
    content['mime_type'],
    content['mimeType'],
    file?['mimetype'],
    file?['mime_type'],
    file?['mimeType'],
  ]);
  if (mimeType != null) {
    info['mimetype'] = mimeType;
  }
  if (url != null) {
    content['url'] = url;
  }
  if (file != null) {
    content['file'] = file;
  }
  content['info'] = info;

  return _eventWithContent(event, content);
}

Event _eventWithContent(Event event, Map<String, dynamic> content) {
  return Event(
    status: event.status,
    content: content,
    type: event.type,
    eventId: event.eventId,
    senderId: event.senderId,
    originServerTs: event.originServerTs,
    unsigned: event.unsigned == null
        ? null
        : Map<String, dynamic>.from(event.unsigned!),
    prevContent: event.prevContent == null
        ? null
        : Map<String, dynamic>.from(event.prevContent!),
    stateKey: event.stateKey,
    room: event.room,
    originalSource: event.originalSource,
  );
}

int? _firstInt(List<Object?> values) {
  for (final value in values) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return null;
}

String? _firstString(List<Object?> values) {
  for (final value in values) {
    if (value is! String) continue;
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return null;
}

Map<String, dynamic>? _firstMap(List<Object?> values) {
  for (final value in values) {
    if (value is! Map) continue;
    return Map<String, dynamic>.from(value);
  }
  return null;
}
