import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/data/recovered_unread_store.dart';

void main() {
  late Directory tempDir;
  late FileRecoveredUnreadStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('portal_unread_store_test');
    store = FileRecoveredUnreadStore(
      File('${tempDir.path}/recovered_unread.json'),
    );
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('merge persists recovered unread and dedupes by event id', () async {
    await store.merge(_unread([
      _room('!a:example.com', [
        _message(r'$1', 'first'),
        _message(r'$2', 'second'),
      ]),
    ]));

    final merged = await store.merge(_unread([
      _room('!a:example.com', [
        _message(r'$2', 'second duplicate'),
        _message(r'$3', 'third'),
      ]),
    ]));

    expect(
      merged.messagesForRoom('!a:example.com').map((m) => m.eventId),
      [r'$1', r'$2', r'$3'],
    );
    expect(
      merged.messagesForRoom('!a:example.com').map((m) => m.content),
      ['first', 'second duplicate', 'third'],
    );

    final loaded = await store.read();
    expect(
      loaded!.messagesForRoom('!a:example.com').map((m) => m.eventId),
      [r'$1', r'$2', r'$3'],
    );
  });

  test('removeRoom clears opened room without touching other rooms', () async {
    await store.merge(_unread([
      _room('!a:example.com', [_message(r'$1', 'first')]),
      _room('!b:example.com', [_message(r'$2', 'second')]),
    ]));

    await store.removeRoom('!a:example.com');

    final loaded = await store.read();
    expect(loaded!.messagesForRoom('!a:example.com'), isEmpty);
    expect(
      loaded.messagesForRoom('!b:example.com').map((m) => m.eventId),
      [r'$2'],
    );
  });

  test('removeEvents clears Matrix timeline duplicates', () async {
    await store.merge(_unread([
      _room('!a:example.com', [
        _message(r'$1', 'first'),
        _message(r'$2', 'second'),
      ]),
    ]));

    await store.removeEvents({r'$1'});

    final loaded = await store.read();
    expect(
      loaded!.messagesForRoom('!a:example.com').map((m) => m.eventId),
      [r'$2'],
    );
  });
}

AsSyncUnread _unread(List<AsUnreadRoom> rooms) {
  return AsSyncUnread(
    syncedAt: DateTime.parse('2026-05-25T10:00:00Z'),
    rooms: rooms,
  );
}

AsUnreadRoom _room(String roomId, List<AsUnreadMessage> messages) {
  return AsUnreadRoom(roomId: roomId, messages: messages);
}

AsUnreadMessage _message(String eventId, String content) {
  return AsUnreadMessage(
    eventId: eventId,
    senderId: '@alice:example.com',
    senderName: 'Alice',
    content: content,
    messageType: 'text',
    timestamp: DateTime.parse('2026-05-25T10:00:00Z'),
  );
}
