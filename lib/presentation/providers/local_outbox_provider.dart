import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/local_outbox_store.dart';

final _localOutboxRuntimeId = DateTime.now().microsecondsSinceEpoch.toString();

class LocalOutboxDraft {
  const LocalOutboxDraft._({
    required this.messageKind,
    this.text = '',
    this.filename = '',
    this.mimeType = '',
    this.bytes,
    this.thumbnailBytes,
    this.width = 0,
    this.height = 0,
    this.durationMs = 0,
    this.createdAt,
  });

  factory LocalOutboxDraft.text({
    required String text,
    DateTime? createdAt,
  }) {
    return LocalOutboxDraft._(
      messageKind: LocalOutboxMessageKind.text,
      text: text,
      createdAt: createdAt,
    );
  }

  factory LocalOutboxDraft.media({
    required LocalOutboxMessageKind messageKind,
    required String filename,
    required String mimeType,
    required Uint8List bytes,
    Uint8List? thumbnailBytes,
    int width = 0,
    int height = 0,
    int durationMs = 0,
    DateTime? createdAt,
  }) {
    assert(messageKind != LocalOutboxMessageKind.text);
    return LocalOutboxDraft._(
      messageKind: messageKind,
      filename: filename,
      mimeType: mimeType,
      bytes: bytes,
      thumbnailBytes: thumbnailBytes,
      width: width,
      height: height,
      durationMs: durationMs,
      createdAt: createdAt,
    );
  }

  final LocalOutboxMessageKind messageKind;
  final String text;
  final String filename;
  final String mimeType;
  final Uint8List? bytes;
  final Uint8List? thumbnailBytes;
  final int width;
  final int height;
  final int durationMs;
  final DateTime? createdAt;
}

class LocalOutboxState {
  const LocalOutboxState({
    this.loaded = false,
    this.items = const [],
  });

  final bool loaded;
  final List<LocalOutboxItem> items;

  List<LocalOutboxItem> itemsForConversation(
    String conversationId, {
    LocalOutboxConversationType? type,
  }) {
    final trimmed = conversationId.trim();
    if (trimmed.isEmpty) return const [];
    return [
      for (final item in items)
        if (item.conversationId == trimmed &&
            (type == null || item.conversationType == type))
          item,
    ];
  }

  LocalOutboxState copyWith({
    bool? loaded,
    List<LocalOutboxItem>? items,
  }) {
    return LocalOutboxState(
      loaded: loaded ?? this.loaded,
      items: List.unmodifiable(items ?? this.items),
    );
  }
}

class LocalOutboxNotifier extends StateNotifier<LocalOutboxState> {
  LocalOutboxNotifier(
    this._loadStore, {
    required this.runtimeId,
  }) : super(const LocalOutboxState()) {
    _loaded = _load();
  }

  final Future<LocalOutboxStore> Function() _loadStore;
  final String runtimeId;
  late final Future<void> _loaded;
  int _idSequence = 0;
  int _batchSequence = 0;

  Future<void> get loaded => _loaded;

  Future<void> _load() async {
    try {
      final store = await _loadStore();
      final items = markStaleLocalOutboxItemsFailed(
        await store.readAll(),
        currentRuntimeId: runtimeId,
      );
      if (!mounted) return;
      state = LocalOutboxState(loaded: true, items: items);
      for (final item in items) {
        await store.upsert(item);
      }
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(loaded: true);
    }
  }

  Future<String> startItem({
    required String conversationId,
    required LocalOutboxConversationType conversationType,
    required LocalOutboxDraft draft,
  }) async {
    final ids = await startItems(
      conversationId: conversationId,
      conversationType: conversationType,
      drafts: [draft],
    );
    return ids.single;
  }

  Future<List<String>> startItems({
    required String conversationId,
    required LocalOutboxConversationType conversationType,
    required List<LocalOutboxDraft> drafts,
  }) async {
    final normalizedConversationId = conversationId.trim();
    if (normalizedConversationId.isEmpty || drafts.isEmpty) return const [];
    await loaded;

    final store = await _loadStore();
    final batchId = _nextBatchId();
    final batchCreatedAt = DateTime.now().toUtc();
    final items = <LocalOutboxItem>[];
    for (var i = 0; i < drafts.length; i++) {
      final draft = drafts[i];
      items.add(
        LocalOutboxItem(
          id: _nextItemId(),
          conversationId: normalizedConversationId,
          conversationType: conversationType,
          messageKind: draft.messageKind,
          text: draft.text,
          filename: draft.filename,
          mimeType: draft.mimeType,
          bytes: draft.bytes,
          thumbnailBytes: draft.thumbnailBytes,
          createdAt:
              draft.createdAt ?? batchCreatedAt.add(Duration(microseconds: i)),
          status: LocalOutboxItemStatus.sending,
          runtimeId: runtimeId,
          batchId: batchId,
          batchIndex: i,
          width: draft.width,
          height: draft.height,
          durationMs: draft.durationMs,
        ),
      );
    }

    for (final item in items) {
      await store.upsert(item);
    }
    state = state.copyWith(items: [
      for (final existing in state.items)
        if (!items.any((item) => item.id == existing.id)) existing,
      ...items,
    ]);
    return [for (final item in items) item.id];
  }

  Future<void> completeItem(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return;
    state = state.copyWith(
      items: [
        for (final item in state.items)
          if (item.id != trimmed) item,
      ],
    );
    await _remove(trimmed);
  }

  Future<void> failItem(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return;
    LocalOutboxItem? failedItem;
    final next = [
      for (final item in state.items)
        if (item.id == trimmed)
          failedItem = item.copyWith(status: LocalOutboxItemStatus.failed)
        else
          item,
    ];
    state = state.copyWith(items: next.whereType<LocalOutboxItem>().toList());
    if (failedItem != null) await _persist(failedItem);
  }

  Future<bool> retryItem(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return false;
    LocalOutboxItem? retryingItem;
    final next = [
      for (final item in state.items)
        if (item.id == trimmed && item.status == LocalOutboxItemStatus.failed)
          retryingItem = item.copyWith(
            status: LocalOutboxItemStatus.sending,
            runtimeId: runtimeId,
          )
        else
          item,
    ];
    if (retryingItem == null) return false;
    state = state.copyWith(items: next.whereType<LocalOutboxItem>().toList());
    await _persist(retryingItem);
    return true;
  }

  String _nextItemId() {
    final sequence = _idSequence++;
    return 'outbox-item-${DateTime.now().microsecondsSinceEpoch}-$sequence';
  }

  String _nextBatchId() {
    final sequence = _batchSequence++;
    return 'outbox-batch-${DateTime.now().microsecondsSinceEpoch}-$sequence';
  }

  Future<void> _persist(LocalOutboxItem item) async {
    try {
      final store = await _loadStore();
      await store.upsert(item);
    } catch (_) {
      // Outbox state is best-effort local UI state; the send pipeline remains
      // controlled by the product route for the current conversation type.
    }
  }

  Future<void> _remove(String id) async {
    try {
      final store = await _loadStore();
      await store.remove(id);
    } catch (_) {
      // A completed item may reappear as failed after a crash if cleanup fails.
      // That is safer than silently losing an unsent message.
    }
  }
}

final localOutboxStoreProvider = FutureProvider<LocalOutboxStore>((ref) async {
  final dir = await getApplicationSupportDirectory();
  return FileLocalOutboxStore(
    File('${dir.path}/portal_im_pending_media_uploads.json'),
  );
});

final localOutboxProvider =
    StateNotifierProvider<LocalOutboxNotifier, LocalOutboxState>((ref) {
  return LocalOutboxNotifier(
    () => ref.read(localOutboxStoreProvider.future),
    runtimeId: _localOutboxRuntimeId,
  );
});
