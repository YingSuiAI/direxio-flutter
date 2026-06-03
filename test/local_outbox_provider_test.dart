import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/local_outbox_store.dart';
import 'package:portal_app/presentation/providers/local_outbox_provider.dart';

void main() {
  test('starts mixed direct message batch with stable order metadata',
      () async {
    final store = _MemoryLocalOutboxStore();
    final notifier = LocalOutboxNotifier(
      () async => store,
      runtimeId: 'runtime-a',
    );
    await notifier.loaded;

    final ids = await notifier.startItems(
      conversationId: '!room:p2p-im.com',
      conversationType: LocalOutboxConversationType.direct,
      drafts: [
        LocalOutboxDraft.text(
          text: 'hello',
          createdAt: DateTime.parse('2026-05-28T10:00:00Z'),
        ),
        LocalOutboxDraft.media(
          messageKind: LocalOutboxMessageKind.image,
          filename: 'first.jpg',
          mimeType: 'image/jpeg',
          bytes: Uint8List.fromList([1]),
          createdAt: DateTime.parse('2026-05-28T10:00:01Z'),
        ),
        LocalOutboxDraft.media(
          messageKind: LocalOutboxMessageKind.video,
          filename: 'clip.mp4',
          mimeType: 'video/mp4',
          bytes: Uint8List.fromList([3]),
          thumbnailBytes: Uint8List.fromList([9]),
          width: 640,
          height: 360,
          durationMs: 2100,
          createdAt: DateTime.parse('2026-05-28T10:00:03Z'),
        ),
        LocalOutboxDraft.media(
          messageKind: LocalOutboxMessageKind.file,
          filename: 'report.pdf',
          mimeType: 'application/pdf',
          bytes: Uint8List.fromList([2]),
          createdAt: DateTime.parse('2026-05-28T10:00:04Z'),
        ),
      ],
    );

    expect(ids, hasLength(4));
    expect(notifier.state.items.map((item) => item.id), ids);
    expect(store.items.map((item) => item.id), ids);
    expect(store.items.map((item) => item.messageKind), [
      LocalOutboxMessageKind.text,
      LocalOutboxMessageKind.image,
      LocalOutboxMessageKind.video,
      LocalOutboxMessageKind.file,
    ]);
    expect(store.items.map((item) => item.batchIndex), [0, 1, 2, 3]);
    expect(store.items.map((item) => item.batchId).toSet(), hasLength(1));
    expect(store.items[2].thumbnailBytes, Uint8List.fromList([9]));
    expect(store.items[2].width, 640);
    expect(store.items[2].height, 360);
    expect(store.items[2].durationMs, 2100);
  });

  test('filters items by conversation id and type', () async {
    final store = _MemoryLocalOutboxStore([
      _item(
        id: 'direct-1',
        conversationId: '!same-id:p2p-im.com',
        conversationType: LocalOutboxConversationType.direct,
      ),
      _item(
        id: 'group-1',
        conversationId: '!same-id:p2p-im.com',
        conversationType: LocalOutboxConversationType.group,
      ),
    ]);
    final notifier = LocalOutboxNotifier(
      () async => store,
      runtimeId: 'runtime-a',
    );
    await notifier.loaded;

    expect(
      notifier.state
          .itemsForConversation(
            '!same-id:p2p-im.com',
            type: LocalOutboxConversationType.direct,
          )
          .map((item) => item.id),
      ['direct-1'],
    );
    expect(
      notifier.state
          .itemsForConversation('!same-id:p2p-im.com')
          .map((item) => item.id),
      ['direct-1', 'group-1'],
    );
  });

  test('complete item waits until persisted item is removed', () async {
    final store = _MemoryLocalOutboxStore();
    final notifier = LocalOutboxNotifier(
      () async => store,
      runtimeId: 'runtime-a',
    );
    await notifier.loaded;
    final ids = await notifier.startItems(
      conversationId: '!room:p2p-im.com',
      conversationType: LocalOutboxConversationType.direct,
      drafts: [
        LocalOutboxDraft.media(
          messageKind: LocalOutboxMessageKind.image,
          filename: 'photo.jpg',
          mimeType: 'image/jpeg',
          bytes: Uint8List.fromList([1]),
        ),
      ],
    );

    await notifier.completeItem(ids.single);

    expect(notifier.state.items, isEmpty);
    expect(store.items, isEmpty);
  });

  test('retry failed item marks it sending with current runtime', () async {
    final createdAt = DateTime.parse('2026-05-28T10:00:00Z');
    final store = _MemoryLocalOutboxStore([
      _item(
        id: 'failed-1',
        conversationId: '!room:p2p-im.com',
        conversationType: LocalOutboxConversationType.direct,
        status: LocalOutboxItemStatus.failed,
        runtimeId: 'old-runtime',
        createdAt: createdAt,
      ),
    ]);
    final notifier = LocalOutboxNotifier(
      () async => store,
      runtimeId: 'runtime-b',
    );
    await notifier.loaded;

    final retried = await notifier.retryItem('failed-1');

    expect(retried, isTrue);
    expect(notifier.state.items.single.status, LocalOutboxItemStatus.sending);
    expect(notifier.state.items.single.runtimeId, 'runtime-b');
    expect(notifier.state.items.single.createdAt, createdAt);
    expect(store.items.single.status, LocalOutboxItemStatus.sending);
    expect(store.items.single.runtimeId, 'runtime-b');
  });
}

LocalOutboxItem _item({
  required String id,
  required String conversationId,
  required LocalOutboxConversationType conversationType,
  LocalOutboxItemStatus status = LocalOutboxItemStatus.sending,
  String runtimeId = 'runtime-a',
  DateTime? createdAt,
}) {
  return LocalOutboxItem(
    id: id,
    conversationId: conversationId,
    conversationType: conversationType,
    messageKind: LocalOutboxMessageKind.image,
    text: '',
    filename: 'photo.jpg',
    mimeType: 'image/jpeg',
    bytes: Uint8List.fromList([1]),
    thumbnailBytes: Uint8List.fromList([1]),
    createdAt: createdAt ?? DateTime.parse('2026-05-28T10:00:00Z'),
    status: status,
    runtimeId: runtimeId,
    batchId: 'batch-1',
    batchIndex: 0,
  );
}

class _MemoryLocalOutboxStore implements LocalOutboxStore {
  _MemoryLocalOutboxStore([List<LocalOutboxItem>? items]) : items = [...?items];

  final List<LocalOutboxItem> items;

  @override
  Future<List<LocalOutboxItem>> readAll() async {
    return [...items];
  }

  @override
  Future<void> upsert(LocalOutboxItem item) async {
    items.removeWhere((existing) => existing.id == item.id);
    items.add(item);
  }

  @override
  Future<void> remove(String id) async {
    items.removeWhere((item) => item.id == id);
  }
}
