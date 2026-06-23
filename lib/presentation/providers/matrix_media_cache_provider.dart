import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matrix/matrix.dart';

final matrixMediaBytesCacheProvider = Provider<MatrixMediaBytesCache>(
  (ref) => MatrixMediaBytesCache(),
);

typedef MatrixEncryptedAttachmentDownloader = Future<Uint8List> Function(
  Client client,
  Map<String, Object?> file, {
  bool thumbnail,
});

class MatrixMediaBytesCache {
  MatrixMediaBytesCache({
    MatrixEncryptedAttachmentDownloader? encryptedAttachmentDownloader,
  }) : _encryptedAttachmentDownloader =
            encryptedAttachmentDownloader ?? _downloadEncryptedAttachmentBytes;

  final MatrixEncryptedAttachmentDownloader _encryptedAttachmentDownloader;
  final Map<String, Future<Uint8List>> _entries = {};

  Future<Uint8List> read(Client client, Uri mxc) {
    final key = mxc.toString();
    final cached = _entries[key];
    if (cached != null) return cached;

    final future = _downloadMatrixMediaBytes(client, mxc);
    _entries[key] = future;
    future.then<void>(
      (_) {},
      onError: (_, __) {
        _entries.remove(key);
      },
    );
    return future;
  }

  Future<Uint8List> readEncryptedAttachment(
    Client client,
    Map<String, Object?> file, {
    bool thumbnail = false,
  }) {
    final key = _encryptedAttachmentCacheKey(file, thumbnail: thumbnail);
    final cached = _entries[key];
    if (cached != null) return cached;

    final future = _encryptedAttachmentDownloader(
      client,
      file,
      thumbnail: thumbnail,
    );
    _entries[key] = future;
    future.then<void>(
      (_) {},
      onError: (_, __) {
        _entries.remove(key);
      },
    );
    return future;
  }

  void clear() => _entries.clear();
}

String _encryptedAttachmentCacheKey(
  Map<String, Object?> file, {
  required bool thumbnail,
}) {
  final url = file['url'];
  final hash = file['hashes'];
  final sha256 = hash is Map ? hash['sha256'] : null;
  return 'encrypted:${thumbnail ? 'thumbnail' : 'file'}:'
      '${url is String ? url : ''}:'
      '${sha256 is String ? sha256 : jsonEncode(file)}';
}

Future<Uint8List> _downloadMatrixMediaBytes(Client client, Uri mxc) async {
  final downloadUri = mxc.getDownloadLink(client);
  if (downloadUri.toString().isEmpty) {
    throw StateError('Matrix homeserver 未就绪');
  }

  final response = await client.httpClient.get(
    downloadUri,
    headers: {
      if ((client.accessToken ?? '').isNotEmpty)
        'authorization': 'Bearer ${client.accessToken}',
    },
  );
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw StateError('媒体下载失败：HTTP ${response.statusCode}');
  }
  return response.bodyBytes;
}

Future<Uint8List> _downloadEncryptedAttachmentBytes(
  Client client,
  Map<String, Object?> file, {
  bool thumbnail = false,
}) async {
  final url = file['url'];
  if (url is! String || Uri.tryParse(url)?.isScheme('mxc') != true) {
    throw StateError('加密媒体地址无效');
  }

  final room = Room(
    id: '!matrix-media-cache:local',
    client: client,
    prev_batch: '',
    roomAccountData: const {},
  );
  final content = <String, dynamic>{
    'msgtype': MessageTypes.Image,
    'body': 'matrix-media',
    if (thumbnail)
      'info': {
        'thumbnail_file': Map<String, Object?>.from(file),
      }
    else
      'file': Map<String, Object?>.from(file),
  };
  final event = Event(
    content: content,
    type: EventTypes.Message,
    eventId: '\$matrix-media-cache',
    senderId: client.userID ?? '@matrix-media-cache:local',
    originServerTs: DateTime.now(),
    room: room,
  );
  final matrixFile = await event.downloadAndDecryptAttachment(
    getThumbnail: thumbnail,
    downloadCallback: (uri) async {
      final response = await client.httpClient.get(
        uri,
        headers: {
          if ((client.accessToken ?? '').isNotEmpty)
            'authorization': 'Bearer ${client.accessToken}',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('媒体下载失败：HTTP ${response.statusCode}');
      }
      return response.bodyBytes;
    },
  );
  return matrixFile.bytes;
}
