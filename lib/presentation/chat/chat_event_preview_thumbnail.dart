import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/chat_event_attachment.dart';
import 'video_thumbnailer.dart';

typedef ChatEventThumbnailDownloader = Future<MatrixFile> Function(Event event);
typedef ChatVideoThumbnailCreator = Future<ChatVideoThumbnail?> Function(
  String path,
);
typedef ChatTemporaryDirectoryProvider = Future<Directory> Function();
typedef ChatPreviewImageValidator = bool Function(Uint8List bytes);

Future<Uint8List> loadChatEventPreviewThumbnail(
  Event event, {
  ChatEventThumbnailDownloader downloadThumbnail = downloadChatEventThumbnail,
  ChatEventThumbnailDownloader downloadAttachment = downloadChatEventAttachment,
  ChatVideoThumbnailCreator createVideoThumbnail = createChatVideoThumbnail,
  ChatTemporaryDirectoryProvider temporaryDirectoryProvider =
      getTemporaryDirectory,
  ChatPreviewImageValidator validateImageBytes =
      isSupportedChatPreviewImageBytes,
}) async {
  try {
    final thumbnail = await downloadThumbnail(event);
    final bytes = thumbnail.bytes;
    if (!validateImageBytes(bytes)) {
      throw StateError('thumbnail bytes are not a supported image');
    }
    return bytes;
  } on Object catch (thumbnailError, stackTrace) {
    if (!_isVideoMessage(event)) rethrow;
    final video = await downloadAttachment(event);
    final videoFile = await _writeTemporaryVideoFile(
      event,
      video,
      temporaryDirectoryProvider,
    );
    try {
      final generated = await createVideoThumbnail(videoFile.path);
      final bytes = generated?.bytes;
      if (bytes != null && bytes.isNotEmpty && validateImageBytes(bytes)) {
        return bytes;
      }
    } finally {
      unawaited(videoFile.delete().catchError((_) => videoFile));
    }
    Error.throwWithStackTrace(thumbnailError, stackTrace);
  }
}

bool isSupportedChatPreviewImageBytes(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return true;
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A) {
    return true;
  }
  if (bytes.length >= 6) {
    final header = String.fromCharCodes(bytes.take(6));
    if (header == 'GIF87a' || header == 'GIF89a') return true;
  }
  if (bytes.length >= 12) {
    final riff = String.fromCharCodes(bytes.take(4));
    final webp = String.fromCharCodes(bytes.skip(8).take(4));
    if (riff == 'RIFF' && webp == 'WEBP') return true;
  }
  return false;
}

Future<File> _writeTemporaryVideoFile(
  Event event,
  MatrixFile video,
  ChatTemporaryDirectoryProvider getTemporaryDirectory,
) async {
  final dir = Directory(
    '${(await getTemporaryDirectory()).path}/p2p-im-video-preview',
  );
  await dir.create(recursive: true);
  final file = File('${dir.path}/${_temporaryVideoFilename(event, video)}');
  await file.writeAsBytes(video.bytes, flush: true);
  return file;
}

String _temporaryVideoFilename(Event event, MatrixFile video) {
  final eventId = event.eventId.trim();
  final videoName = chatEventAttachmentFileName(
    event,
    video,
    fallbackName: event.body.trim().isEmpty ? 'video-preview' : event.body,
  );
  final extension = _fileExtension(videoName) ?? '.mp4';
  final base = eventId.isEmpty ? videoName : eventId;
  final safe = base.replaceAll(RegExp(r'[^A-Za-z0-9_.-]+'), '_');
  if (safe.isEmpty) return 'video-preview$extension';
  if (_hasFileExtension(safe)) return safe;
  return '$safe$extension';
}

String? _fileExtension(String filename) {
  final dot = filename.lastIndexOf('.');
  if (dot >= 0 && dot < filename.length - 1) {
    final ext = filename.substring(dot).toLowerCase();
    if (RegExp(r'^\.[a-z0-9]{2,5}$').hasMatch(ext)) return ext;
  }
  return null;
}

bool _hasFileExtension(String filename) {
  final dot = filename.lastIndexOf('.');
  return dot > 0 && dot < filename.length - 1;
}

bool _isVideoMessage(Event event) {
  return event.content['msgtype']?.toString() == MessageTypes.Video;
}
