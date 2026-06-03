import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:portal_app/data/local_message_order_store.dart';
import 'package:portal_app/data/local_outbox_store.dart';
import 'package:portal_app/presentation/providers/local_message_order_provider.dart';

void main() {
  test('records delivered outbox order by event id', () async {
    final store = _MemoryOrderStore();
    final container = ProviderContainer(
      overrides: [
        localMessageOrderStoreProvider.overrideWith((ref) async => store),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(localMessageOrderProvider.notifier)
        .recordDeliveredOutbox(
          outbox: _outboxItem(batchIndex: 2),
          eventId: r'$event-2',
        );

    final entry =
        container.read(localMessageOrderProvider).entryForEvent(r'$event-2');
    expect(entry, isNotNull);
    expect(entry!.createdAt, DateTime.parse('2026-05-28T14:17:00.000002Z'));
    expect(entry.batchIndex, 2);
    expect(store.entries.single.eventId, r'$event-2');
  });
}

LocalOutboxItem _outboxItem({required int batchIndex}) {
  return LocalOutboxItem(
    id: 'outbox-$batchIndex',
    conversationId: '!room:p2p-im.com',
    conversationType: LocalOutboxConversationType.direct,
    messageKind: LocalOutboxMessageKind.image,
    text: '',
    filename: 'image-$batchIndex.jpg',
    mimeType: 'image/jpeg',
    bytes: null,
    createdAt: DateTime.parse('2026-05-28T14:17:00Z').add(
      Duration(microseconds: batchIndex),
    ),
    status: LocalOutboxItemStatus.sending,
    runtimeId: 'runtime',
    batchId: 'batch-1',
    batchIndex: batchIndex,
  );
}

class _MemoryOrderStore implements LocalMessageOrderStore {
  final entries = <LocalMessageOrderEntry>[];

  @override
  Future<List<LocalMessageOrderEntry>> readAll() async => entries;

  @override
  Future<void> upsert(LocalMessageOrderEntry entry) async {
    entries.removeWhere((existing) => existing.eventId == entry.eventId);
    entries.add(entry);
  }
}
