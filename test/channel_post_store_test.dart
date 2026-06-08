import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/data/channel_post_store.dart';

void main() {
  late Directory tempDir;
  late File file;
  late FileChannelPostStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('portal_channel_posts');
    file = File('${tempDir.path}/channel_posts.json');
    store = FileChannelPostStore(file);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('persists channel posts newest first and scoped by channel id',
      () async {
    await store.upsertChannel('ch_1', [
      _post(postId: 'old', channelId: 'ch_1', ts: 1000),
      _post(postId: 'new', channelId: 'ch_1', ts: 3000),
      _post(postId: 'other', channelId: 'ch_2', ts: 4000),
    ]);

    final loaded = await store.readChannel('ch_1');

    expect(loaded.map((post) => post.postId), ['new', 'old']);
  });

  test('upsert replaces posts by stable id instead of duplicating them',
      () async {
    await store.upsertPost(
      _post(postId: 'post_1', eventId: r'$event_1', body: '旧内容'),
    );
    await store.upsertPost(
      _post(postId: 'post_1', eventId: r'$event_1', body: '新内容'),
    );

    final loaded = await store.readChannel('ch_1');

    expect(loaded, hasLength(1));
    expect(loaded.single.body, '新内容');
  });
}

AsChannelPost _post({
  required String postId,
  String channelId = 'ch_1',
  String roomId = '!channel:p2p-im.com',
  String eventId = '',
  String body = '频道内容',
  int ts = 1000,
}) {
  return AsChannelPost(
    postId: postId,
    channelId: channelId,
    roomId: roomId,
    eventId: eventId,
    authorId: '@owner:p2p-im.com',
    authorName: 'Yanan',
    messageType: 'text',
    body: body,
    originServerTs: ts,
  );
}
