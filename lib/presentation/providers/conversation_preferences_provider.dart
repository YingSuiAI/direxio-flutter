import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/conversation_preferences_store.dart';

class ConversationPreferencesState {
  const ConversationPreferencesState({
    this.pinnedConversationIds = const {},
    this.groupRemarkNames = const {},
  });

  final Set<String> pinnedConversationIds;
  final Map<String, String> groupRemarkNames;

  ConversationPreferencesState copyWith({
    Set<String>? pinnedConversationIds,
    Map<String, String>? groupRemarkNames,
  }) {
    return ConversationPreferencesState(
      pinnedConversationIds:
          Set.unmodifiable(pinnedConversationIds ?? this.pinnedConversationIds),
      groupRemarkNames:
          Map.unmodifiable(groupRemarkNames ?? this.groupRemarkNames),
    );
  }
}

final conversationPreferencesStoreProvider =
    FutureProvider<ConversationPreferencesStore>((ref) async {
  final dir = await getApplicationSupportDirectory();
  return FileConversationPreferencesStore(
    File('${dir.path}/portal_im_conversation_preferences.json'),
  );
});

final conversationPreferencesProvider = StateNotifierProvider<
    ConversationPreferencesController, ConversationPreferencesState>((ref) {
  return ConversationPreferencesController(ref);
});

final pinnedConversationIdsProvider = Provider<Set<String>>((ref) {
  return ref.watch(conversationPreferencesProvider).pinnedConversationIds;
});

final groupRemarkNamesProvider = Provider<Map<String, String>>((ref) {
  return ref.watch(conversationPreferencesProvider).groupRemarkNames;
});

class ConversationPreferencesController
    extends StateNotifier<ConversationPreferencesState> {
  ConversationPreferencesController(this.ref)
      : super(const ConversationPreferencesState()) {
    unawaited(_load());
  }

  final Ref ref;

  Future<void> _load() async {
    try {
      final store = await ref.read(conversationPreferencesStoreProvider.future);
      final data = await store.read();
      state = state.copyWith(
        pinnedConversationIds: data.pinnedConversationIds,
        groupRemarkNames: data.groupRemarkNames,
      );
    } catch (_) {
      // Preferences are non-critical; keep the in-memory defaults.
    }
  }

  void togglePin(String roomId) {
    final trimmed = roomId.trim();
    if (trimmed.isEmpty) return;
    final next = {...state.pinnedConversationIds};
    if (!next.remove(trimmed)) next.add(trimmed);
    state = state.copyWith(pinnedConversationIds: next);
    _persist();
  }

  void unpin(String roomId) {
    final trimmed = roomId.trim();
    if (trimmed.isEmpty || !state.pinnedConversationIds.contains(trimmed)) {
      return;
    }
    final next = {...state.pinnedConversationIds}..remove(trimmed);
    state = state.copyWith(pinnedConversationIds: next);
    _persist();
  }

  void setGroupRemark(String roomId, String name) {
    final trimmedRoomId = roomId.trim();
    if (trimmedRoomId.isEmpty) return;
    final next = Map<String, String>.from(state.groupRemarkNames);
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      next.remove(trimmedRoomId);
    } else {
      next[trimmedRoomId] = trimmedName;
    }
    state = state.copyWith(groupRemarkNames: next);
    _persist();
  }

  void _persist() {
    unawaited(
      ref
          .read(conversationPreferencesStoreProvider.future)
          .then(
            (store) => store.write(
              ConversationPreferencesData(
                pinnedConversationIds: state.pinnedConversationIds,
                groupRemarkNames: state.groupRemarkNames,
              ),
            ),
          )
          .catchError((_) {}),
    );
  }
}

void toggleConversationPin(WidgetRef ref, String roomId) {
  ref.read(conversationPreferencesProvider.notifier).togglePin(roomId);
}

void unpinConversation(WidgetRef ref, String roomId) {
  ref.read(conversationPreferencesProvider.notifier).unpin(roomId);
}

void setGroupRemarkName(WidgetRef ref, String roomId, String name) {
  ref
      .read(conversationPreferencesProvider.notifier)
      .setGroupRemark(roomId, name);
}
