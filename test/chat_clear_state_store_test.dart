import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/chat_clear_state_store.dart';

void main() {
  late Directory tempDir;
  late FileChatClearStateStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'portal_chat_clear_state_test',
    );
    store = FileChatClearStateStore(
      File('${tempDir.path}/portal_im_chat_clear_state.json'),
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('persists and clears chat clear boundary', () async {
    expect(await store.readClearedBeforeTs(), 0);

    await store.writeClearedBeforeTs(1234);
    expect(await store.readClearedBeforeTs(), 1234);

    await store.writeRoomClearedBeforeTs('!group:example.com', 2345);
    expect(await store.readRoomClearedBeforeTs(), {
      '!group:example.com': 2345,
    });
    expect(await store.readClearedBeforeTs(), 1234);

    await store.clear();
    expect(await store.readClearedBeforeTs(), 0);
    expect(await store.readRoomClearedBeforeTs(), isEmpty);
  });
}
