import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matrix/matrix.dart';

final matrixMediaBytesCacheProvider = Provider<MatrixMediaBytesCache>(
  (ref) => MatrixMediaBytesCache(),
);

class MatrixMediaBytesCache {
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

  void clear() => _entries.clear();
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
