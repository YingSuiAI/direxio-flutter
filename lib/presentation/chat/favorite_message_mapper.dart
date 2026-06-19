import '../../data/as_client.dart';
import '../utils/contact_identity_label.dart';
import 'chat_record_forwarding.dart';

AsFavoriteMessageDraft favoriteDraftFromMatrixMessage({
  required String roomId,
  required String eventId,
  required String roomType,
  required String senderId,
  String senderName = '',
  required String body,
  required Map<String, Object?> content,
  required int originServerTs,
  String savedMediaUrl = '',
  String savedThumbnailUrl = '',
}) {
  final msgType = _string(content['msgtype']);
  final info = _map(content['info']);
  final file = _map(content['file']);
  final thumbnailInfo = _map(info['thumbnail_info']);
  final thumbnailFile = _map(info['thumbnail_file']);
  final contentBody = _string(content['body']);
  final displayBody = body.trim().isNotEmpty ? body.trim() : contentBody;
  final chatRecordTitle = chatRecordTitleFromContent(content);
  if (chatRecordTitle != null) {
    final chatRecord = _map(content[chatRecordMatrixPayloadKey]);
    return AsFavoriteMessageDraft(
      roomId: roomId,
      eventId: eventId,
      roomType: roomType,
      messageType: chatRecordMessageType,
      senderId: senderId,
      senderName: senderName,
      body: chatRecordTitle,
      originServerTs: originServerTs,
      chatRecord: chatRecord,
    );
  }

  final link = firstUrlInText(displayBody);
  final originalMediaUrl = _string(content['url']).isNotEmpty
      ? _string(content['url'])
      : _string(file['url']);
  final originalThumbnailUrl = _string(info['thumbnail_url']).isNotEmpty
      ? _string(info['thumbnail_url'])
      : _string(thumbnailFile['url']);
  final messageType = _favoriteMessageType(msgType, link);
  final filename = _string(content['filename']).isNotEmpty
      ? _string(content['filename'])
      : displayBody;

  return AsFavoriteMessageDraft(
    roomId: roomId,
    eventId: eventId,
    roomType: roomType,
    messageType: messageType,
    senderId: senderId,
    senderName: senderName,
    body: displayBody,
    url: savedMediaUrl.trim().isNotEmpty
        ? savedMediaUrl.trim()
        : messageType == 'link'
            ? link
            : originalMediaUrl,
    filename: filename,
    mimeType: _string(info['mimetype']).isNotEmpty
        ? _string(info['mimetype'])
        : _string(file['mimetype']),
    size: _int(info['size']),
    thumbnailUrl: savedThumbnailUrl.trim().isNotEmpty
        ? savedThumbnailUrl.trim()
        : originalThumbnailUrl,
    thumbnailMimeType: _string(thumbnailInfo['mimetype']).isNotEmpty
        ? _string(thumbnailInfo['mimetype'])
        : _string(thumbnailFile['mimetype']),
    thumbnailSize: _int(thumbnailInfo['size']),
    width: _int(info['w']),
    height: _int(info['h']),
    durationMs: _int(info['duration']),
    originServerTs: originServerTs,
  );
}

String firstUrlInText(String text) {
  final match = RegExp(r'https?://[^\s]+').firstMatch(text);
  return match?.group(0) ?? '';
}

bool favoriteMediaNeedsOwnerCopy({
  required String mediaUrl,
  required String ownerUserId,
}) {
  final uri = Uri.tryParse(mediaUrl.trim());
  if (uri == null || uri.scheme != 'mxc' || uri.host.isEmpty) return false;
  final ownerDomain = ownerUserIdDomain(ownerUserId);
  return ownerDomain.isNotEmpty && uri.host != ownerDomain;
}

String ownerUserIdDomain(String ownerUserId) {
  return domainFromMxid(ownerUserId);
}

bool isFavoriteMediaMessageType(String messageType) {
  return messageType == 'image' ||
      messageType == 'video' ||
      messageType == 'file' ||
      messageType == 'audio';
}

String _favoriteMessageType(String msgType, String link) {
  switch (msgType) {
    case 'm.image':
      return 'image';
    case 'm.video':
      return 'video';
    case 'm.file':
      return 'file';
    case 'm.audio':
      return 'audio';
    default:
      return link.isNotEmpty ? 'link' : 'text';
  }
}

Map<String, Object?> _map(Object? value) {
  if (value is Map) return value.cast<String, Object?>();
  return const {};
}

String _string(Object? value) {
  if (value is String) return value.trim();
  return '';
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
