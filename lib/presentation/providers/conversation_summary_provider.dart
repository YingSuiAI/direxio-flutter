import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/conversation_summary_store.dart';

final conversationSummaryStoreProvider =
    FutureProvider<ConversationSummaryStore>((ref) async {
  final dir = await getApplicationSupportDirectory();
  return FileConversationSummaryStore(
    File('${dir.path}/conversation_summary.json'),
  );
});

class ConversationSummaryNotifier
    extends StateNotifier<ConversationSummaryState> {
  ConversationSummaryNotifier(this._loadStore)
      : super(const ConversationSummaryState()) {
    _loaded = _load();
  }

  final Future<ConversationSummaryStore> Function() _loadStore;
  late final Future<void> _loaded;

  Future<void> get loaded => _loaded;

  Future<void> _load() async {
    try {
      final store = await _loadStore();
      final snapshot = await store.read();
      if (!mounted) return;
      if (snapshot == null) {
        state = state.copyWith(loaded: true);
        return;
      }
      state = ConversationSummaryState.fromSnapshot(snapshot);
    } catch (error) {
      debugPrint('load conversation summary failed: $error');
      if (!mounted) return;
      state = state.copyWith(loaded: true);
    }
  }

  Future<void> replaceForUser({
    required String? userId,
    required List<ConversationSummaryEntry> entries,
  }) async {
    final owner = userId?.trim() ?? '';
    if (owner.isEmpty || entries.isEmpty) return;
    await loaded;
    final nextEntries = List<ConversationSummaryEntry>.unmodifiable(entries);
    if (state.loaded &&
        state.userId == owner &&
        listEquals(state.entries, nextEntries)) {
      return;
    }
    final nextState = ConversationSummaryState(
      loaded: true,
      userId: owner,
      entries: nextEntries,
      updatedAt: DateTime.now().toUtc(),
    );
    state = nextState;
    final snapshot = nextState.toSnapshot();
    if (snapshot == null) return;
    try {
      final store = await _loadStore();
      await store.write(snapshot);
    } catch (error) {
      debugPrint('persist conversation summary failed: $error');
    }
  }
}

final conversationSummaryProvider = StateNotifierProvider<
    ConversationSummaryNotifier, ConversationSummaryState>(
  (ref) {
    return ConversationSummaryNotifier(
      () => ref.read(conversationSummaryStoreProvider.future),
    );
  },
);
