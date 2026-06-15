import 'package:matrix/matrix.dart';

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
