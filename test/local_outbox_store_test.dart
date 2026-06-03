import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/local_outbox_store.dart';

void main() {
  late Directory tempDir;
  late File file;
  late FileLocalOutboxStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('portal_outbox_test');
    file = File('${tempDir.path}/outbox.json');
    store = FileLocalOutboxStore(file);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('persists mixed text image video and file outbox items', () async {
    await store.upsert(_item(
      id: 'text-1',
      messageKind: LocalOutboxMessageKind.text,
      text: 'hello',
      bytes: null,
      batchIndex: 0,
    ));
    await store.upsert(_item(
      id: 'image-1',
      messageKind: LocalOutboxMessageKind.image,
      filename: 'photo.jpg',
      mimeType: 'image/jpeg',
      bytes: [1, 2, 3],
      batchIndex: 1,
    ));
    await store.upsert(_item(
      id: 'video-1',
      messageKind: LocalOutboxMessageKind.video,
      filename: 'clip.mp4',
      mimeType: 'video/mp4',
      bytes: [6, 7, 8],
      batchIndex: 2,
    ));
    await store.upsert(_item(
      id: 'file-1',
      messageKind: LocalOutboxMessageKind.file,
      filename: 'report.pdf',
      mimeType: 'application/pdf',
      bytes: [4, 5],
      batchIndex: 3,
    ));

    final loaded = await store.readAll();

    expect(loaded.map((item) => item.id), [
      'text-1',
      'image-1',
      'video-1',
      'file-1',
    ]);
    expect(loaded.map((item) => item.conversationType), [
      LocalOutboxConversationType.direct,
      LocalOutboxConversationType.direct,
      LocalOutboxConversationType.direct,
      LocalOutboxConversationType.direct,
    ]);
    expect(loaded.map((item) => item.messageKind), [
      LocalOutboxMessageKind.text,
      LocalOutboxMessageKind.image,
      LocalOutboxMessageKind.video,
      LocalOutboxMessageKind.file,
    ]);
    expect(loaded.map((item) => item.batchIndex), [0, 1, 2, 3]);
    expect(loaded.first.text, 'hello');
    expect(loaded[1].bytes, Uint8List.fromList([1, 2, 3]));
  });

  test('loads legacy pending media json as direct image outbox item', () async {
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode([
      {
        'id': 'legacy-image',
        'room_id': '!room:p2p-im.com',
        'filename': 'photo.jpg',
        'mime_type': 'image/jpeg',
        'bytes': base64Encode([1, 2, 3]),
        'created_at': '2026-05-28T10:00:00.000Z',
        'status': 'sending',
        'runtime_id': 'runtime-a',
      }
    ]));

    final loaded = await store.readAll();

    expect(loaded, hasLength(1));
    expect(loaded.single.conversationId, '!room:p2p-im.com');
    expect(loaded.single.conversationType, LocalOutboxConversationType.direct);
    expect(loaded.single.messageKind, LocalOutboxMessageKind.image);
    expect(loaded.single.bytes, Uint8List.fromList([1, 2, 3]));
  });

  test('loads thumbnail metadata without requiring eager full image decode',
      () async {
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode([
      {
        'id': 'failed-image',
        'conversation_id': '!room:p2p-im.com',
        'conversation_type': 'direct',
        'message_kind': 'image',
        'filename': 'photo.jpg',
        'mime_type': 'image/jpeg',
        'bytes': base64Encode([1, 2, 3, 4, 5, 6]),
        'thumbnail_bytes': base64Encode([7, 8, 9]),
        'byte_length': 6,
        'created_at': '2026-05-28T10:00:00.000Z',
        'status': 'failed',
        'runtime_id': 'runtime-a',
      }
    ]));

    final loaded = await store.readAll();

    expect(loaded.single.thumbnailBytes, Uint8List.fromList([7, 8, 9]));
    expect(loaded.single.byteLength, 6);
    expect(loaded.single.hasOriginalBytes, isTrue);
  });

  test('persists video thumbnail dimensions and duration', () async {
    await store.upsert(_item(
      id: 'video-1',
      messageKind: LocalOutboxMessageKind.video,
      filename: 'clip.mp4',
      mimeType: 'video/mp4',
      bytes: [1, 2, 3],
      width: 640,
      height: 360,
      durationMs: 2100,
    ));

    final loaded = await store.readAll();

    expect(loaded.single.thumbnailBytes, Uint8List.fromList([1, 2, 3]));
    expect(loaded.single.width, 640);
    expect(loaded.single.height, 360);
    expect(loaded.single.durationMs, 2100);
  });

  test('marks sending items from previous app process as failed', () async {
    final current = _item(
      id: 'current',
      status: LocalOutboxItemStatus.sending,
      runtimeId: 'runtime-current',
    );
    final stale = _item(
      id: 'stale',
      status: LocalOutboxItemStatus.sending,
      runtimeId: 'runtime-old',
    );

    final resolved = markStaleLocalOutboxItemsFailed(
      [current, stale],
      currentRuntimeId: 'runtime-current',
    );

    expect(
      resolved.map((item) => '${item.id}:${item.status.name}'),
      ['current:sending', 'stale:failed'],
    );
  });
}

LocalOutboxItem _item({
  required String id,
  LocalOutboxConversationType conversationType =
      LocalOutboxConversationType.direct,
  LocalOutboxMessageKind messageKind = LocalOutboxMessageKind.image,
  String text = '',
  String filename = 'photo.jpg',
  String mimeType = 'image/jpeg',
  List<int>? bytes = const [1],
  int batchIndex = 0,
  LocalOutboxItemStatus status = LocalOutboxItemStatus.failed,
  String runtimeId = 'runtime-a',
  int width = 0,
  int height = 0,
  int durationMs = 0,
}) {
  return LocalOutboxItem(
    id: id,
    conversationId: '!room:p2p-im.com',
    conversationType: conversationType,
    messageKind: messageKind,
    text: text,
    filename: filename,
    mimeType: mimeType,
    bytes: bytes == null ? null : Uint8List.fromList(bytes),
    thumbnailBytes: bytes == null ? null : Uint8List.fromList(bytes),
    createdAt: DateTime.parse('2026-05-28T10:00:00Z'),
    status: status,
    runtimeId: runtimeId,
    batchId: 'batch-1',
    batchIndex: batchIndex,
    width: width,
    height: height,
    durationMs: durationMs,
  );
}
