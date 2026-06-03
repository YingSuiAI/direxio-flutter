import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/friend_request_read_store.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'portal_friend_request_read_store_test',
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('persists read friend request room ids', () async {
    final store = FileFriendRequestReadStore(
      File('${tempDir.path}/friend_requests.json'),
    );

    expect(await store.readRoomIds(), isEmpty);

    await store.writeRoomIds({'!incoming:p2p-im.com'});

    expect(await store.readRoomIds(), {'!incoming:p2p-im.com'});
  });
}
