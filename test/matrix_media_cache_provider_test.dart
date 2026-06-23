import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/presentation/providers/matrix_media_cache_provider.dart';

void main() {
  test('encrypted attachments are cached through the encrypted downloader',
      () async {
    final client = Client('MatrixMediaEncryptedCacheTest')
      ..setUserId('@me:p2p-im.com');
    var calls = 0;
    final cache = MatrixMediaBytesCache(
      encryptedAttachmentDownloader: (client, file, {thumbnail = false}) async {
        calls++;
        expect(file['url'], 'mxc://p2p-im.com/encrypted');
        expect(thumbnail, isTrue);
        return Uint8List.fromList([1, 2, 3]);
      },
    );
    final file = <String, Object?>{
      'url': 'mxc://p2p-im.com/encrypted',
      'hashes': {'sha256': 'same'},
    };

    final first = await cache.readEncryptedAttachment(
      client,
      file,
      thumbnail: true,
    );
    final second = await cache.readEncryptedAttachment(
      client,
      file,
      thumbnail: true,
    );

    expect(first, [1, 2, 3]);
    expect(identical(first, second), isTrue);
    expect(calls, 1);
  });

  test('failed encrypted attachment downloads are evicted', () async {
    final client = Client('MatrixMediaEncryptedRetryTest')
      ..setUserId('@me:p2p-im.com');
    var calls = 0;
    final cache = MatrixMediaBytesCache(
      encryptedAttachmentDownloader: (client, file, {thumbnail = false}) async {
        calls++;
        if (calls == 1) throw StateError('decrypt failed');
        return Uint8List.fromList([4]);
      },
    );
    final file = <String, Object?>{
      'url': 'mxc://p2p-im.com/encrypted',
      'hashes': {'sha256': 'retry'},
    };

    await expectLater(
      cache.readEncryptedAttachment(client, file),
      throwsStateError,
    );
    final recovered = await cache.readEncryptedAttachment(client, file);

    expect(recovered, [4]);
    expect(calls, 2);
  });
}
