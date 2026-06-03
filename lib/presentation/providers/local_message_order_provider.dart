import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/local_message_order_store.dart';
import '../../data/local_outbox_store.dart';

class LocalMessageOrderState {
  const LocalMessageOrderState({
    this.loaded = false,
    this.entries = const [],
  });

  final bool loaded;
  final List<LocalMessageOrderEntry> entries;

  List<LocalMessageOrderEntry> entriesForConversation(
    String conversationId, {
    LocalOutboxConversationType? type,
  }) {
    final trimmed = conversationId.trim();
    if (trimmed.isEmpty) return const [];
    return [
      for (final entry in entries)
        if (entry.conversationId == trimmed &&
            (type == null || entry.conversationType == type))
          entry,
    ];
  }

  LocalMessageOrderEntry? entryForEvent(String eventId) {
    final trimmed = eventId.trim();
    if (trimmed.isEmpty) return null;
    for (final entry in entries) {
      if (entry.eventId == trimmed) return entry;
    }
    return null;
  }

  LocalMessageOrderState copyWith({
    bool? loaded,
    List<LocalMessageOrderEntry>? entries,
  }) {
    return LocalMessageOrderState(
      loaded: loaded ?? this.loaded,
      entries: List.unmodifiable(entries ?? this.entries),
    );
  }
}

class LocalMessageOrderNotifier extends StateNotifier<LocalMessageOrderState> {
  LocalMessageOrderNotifier(this._loadStore)
      : super(const LocalMessageOrderState()) {
    _loaded = _load();
  }

  final Future<LocalMessageOrderStore> Function() _loadStore;
  late final Future<void> _loaded;

  Future<void> get loaded => _loaded;

  Future<void> _load() async {
    try {
      final store = await _loadStore();
      state = LocalMessageOrderState(
        loaded: true,
        entries: await store.readAll(),
      );
    } catch (_) {
      state = state.copyWith(loaded: true);
    }
  }

  Future<void> recordDeliveredOutbox({
    required LocalOutboxItem outbox,
    required String eventId,
  }) async {
    final trimmedEventId = eventId.trim();
    if (trimmedEventId.isEmpty) return;
    await loaded;
    final entry = LocalMessageOrderEntry(
      eventId: trimmedEventId,
      conversationId: outbox.conversationId,
      conversationType: outbox.conversationType,
      createdAt: outbox.createdAt,
      batchId: outbox.batchId,
      batchIndex: outbox.batchIndex,
    );
    state = state.copyWith(entries: [
      for (final existing in state.entries)
        if (existing.eventId != trimmedEventId) existing,
      entry,
    ]);
    try {
      final store = await _loadStore();
      await store.upsert(entry);
    } catch (_) {
      // Presentation order metadata is an optimization. Losing it must not
      // block the actual send lifecycle or leave outbox items stuck.
    }
  }
}

final localMessageOrderStoreProvider =
    FutureProvider<LocalMessageOrderStore>((ref) async {
  final dir = await getApplicationSupportDirectory();
  return FileLocalMessageOrderStore(
    File('${dir.path}/portal_im_local_message_order.json'),
  );
});

final localMessageOrderProvider =
    StateNotifierProvider<LocalMessageOrderNotifier, LocalMessageOrderState>(
        (ref) {
  return LocalMessageOrderNotifier(
    () => ref.read(localMessageOrderStoreProvider.future),
  );
});
