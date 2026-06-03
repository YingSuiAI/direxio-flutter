import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/local_outbox_store.dart';
import 'package:portal_app/presentation/chat/chat_media_send_flow.dart';
import 'package:portal_app/presentation/chat/product_media_outbox_flow.dart';
import 'package:portal_app/presentation/providers/local_outbox_provider.dart';

void main() {
  test('starts grouped image outbox items with stable selection order',
      () async {
    final store = _MemoryLocalOutboxStore();
    final notifier = LocalOutboxNotifier(
      () async => store,
      runtimeId: 'runtime-a',
    );
    await notifier.loaded;

    final ids = await startImageOutboxItems(
      notifier: notifier,
      conversationId: '!group:p2p-im.com',
      conversationType: LocalOutboxConversationType.group,
      attachments: [
        ChatMediaAttachment.image(
          name: 'first.jpg',
          bytes: _transparentPng,
          mimeType: 'image/jpeg',
        ),
        ChatMediaAttachment.image(
          name: 'second.jpg',
          bytes: _transparentPng,
          mimeType: 'image/jpeg',
        ),
      ],
    );

    expect(ids, hasLength(2));
    expect(store.items.map((item) => item.id), ids);
    expect(store.items.map((item) => item.conversationType), [
      LocalOutboxConversationType.group,
      LocalOutboxConversationType.group,
    ]);
    expect(store.items.map((item) => item.conversationId).toSet(), {
      '!group:p2p-im.com',
    });
    expect(store.items.map((item) => item.filename), [
      'first.jpg',
      'second.jpg',
    ]);
    expect(store.items.map((item) => item.batchIndex), [0, 1]);
    expect(store.items.every((item) => item.thumbnailBytes != null), isTrue);
  });

  test('builds video and file outbox drafts without direct-chat assumptions',
      () async {
    final videoDraft = mediaOutboxDraftForAttachment(
      ChatMediaAttachment.video(
        name: 'clip.mov',
        bytes: [1, 2, 3],
        mimeType: '',
        thumbnailBytes: [9],
        width: 640,
        height: 360,
        durationMs: 2100,
      ),
    );
    final fileDraft = mediaOutboxDraftForAttachment(
      ChatMediaAttachment.file(
        name: 'report.pdf',
        bytes: [4, 5],
        mimeType: 'application/pdf',
      ),
    );

    expect(videoDraft.messageKind, LocalOutboxMessageKind.video);
    expect(videoDraft.mimeType, 'video/quicktime');
    expect(videoDraft.thumbnailBytes, Uint8List.fromList([9]));
    expect(videoDraft.width, 640);
    expect(videoDraft.height, 360);
    expect(videoDraft.durationMs, 2100);
    expect(fileDraft.messageKind, LocalOutboxMessageKind.file);
    expect(fileDraft.mimeType, 'application/pdf');
    expect(outboxFileSizeLabel(_itemFromDraft(fileDraft)), 'PDF · 2 B');
  });
}

LocalOutboxItem _itemFromDraft(LocalOutboxDraft draft) {
  return LocalOutboxItem(
    id: 'outbox-1',
    conversationId: '!room:p2p-im.com',
    conversationType: LocalOutboxConversationType.group,
    messageKind: draft.messageKind,
    text: draft.text,
    filename: draft.filename,
    mimeType: draft.mimeType,
    bytes: draft.bytes,
    thumbnailBytes: draft.thumbnailBytes,
    createdAt: DateTime.utc(2026, 5, 30, 10),
    status: LocalOutboxItemStatus.sending,
    runtimeId: 'runtime-a',
    batchId: 'batch-1',
    batchIndex: 0,
    width: draft.width,
    height: draft.height,
    durationMs: draft.durationMs,
  );
}

class _MemoryLocalOutboxStore implements LocalOutboxStore {
  final items = <LocalOutboxItem>[];

  @override
  Future<List<LocalOutboxItem>> readAll() async => [...items];

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

final _transparentPng = Uint8List.fromList([
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);
