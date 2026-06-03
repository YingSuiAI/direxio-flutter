import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/local_message_order_store.dart';
import 'package:portal_app/data/local_outbox_store.dart';

void main() {
  late Directory tempDir;
  late File file;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('portal_order_test');
    file = File('${tempDir.path}/orders.json');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('persists delivered message local order metadata', () async {
    final store = FileLocalMessageOrderStore(file);
    await store.upsert(
      LocalMessageOrderEntry(
        eventId: r'$event-1',
        conversationId: '!room:p2p-im.com',
        conversationType: LocalOutboxConversationType.direct,
        createdAt: DateTime.parse('2026-05-28T14:17:00Z'),
        batchId: 'batch-1',
        batchIndex: 0,
      ),
    );

    final loaded = await store.readAll();

    expect(loaded.single.eventId, r'$event-1');
    expect(loaded.single.createdAt, DateTime.parse('2026-05-28T14:17:00Z'));
    expect(loaded.single.batchId, 'batch-1');
    expect(loaded.single.batchIndex, 0);
  });

  test('upsert replaces existing event order instead of duplicating it',
      () async {
    final store = FileLocalMessageOrderStore(file);
    await store.upsert(_entry(r'$event', batchIndex: 0));
    await store.upsert(_entry(r'$event', batchIndex: 1));

    final loaded = await store.readAll();

    expect(loaded, hasLength(1));
    expect(loaded.single.batchIndex, 1);
  });
}

LocalMessageOrderEntry _entry(String eventId, {required int batchIndex}) {
  return LocalMessageOrderEntry(
    eventId: eventId,
    conversationId: '!room:p2p-im.com',
    conversationType: LocalOutboxConversationType.direct,
    createdAt: DateTime.parse('2026-05-28T14:17:00Z').add(
      Duration(microseconds: batchIndex),
    ),
    batchId: 'batch-1',
    batchIndex: batchIndex,
  );
}
