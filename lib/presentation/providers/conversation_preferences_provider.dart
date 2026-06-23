import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/conversation_preferences_store.dart';

class ConversationPreferencesState {
  const ConversationPreferencesState({
    this.pinnedConversationIds = const {},
    this.groupRemarkNames = const {},
    this.groupAvatarMemberOrders = const {},
    Set<String> mutedConversationIds = const {},
    Set<String> hiddenConversationIds = const {},
  })  : _mutedConversationIds = mutedConversationIds,
        _hiddenConversationIds = hiddenConversationIds;

  final Set<String> pinnedConversationIds;
  final Map<String, String> groupRemarkNames;
  final Map<String, List<String>> groupAvatarMemberOrders;
  final Set<String>? _mutedConversationIds;
  final Set<String>? _hiddenConversationIds;

  Set<String> get mutedConversationIds => _mutedConversationIds ?? const {};

  Set<String> get hiddenConversationIds => _hiddenConversationIds ?? const {};

  ConversationPreferencesState copyWith({
    Set<String>? pinnedConversationIds,
    Map<String, String>? groupRemarkNames,
    Map<String, List<String>>? groupAvatarMemberOrders,
    Set<String>? mutedConversationIds,
    Set<String>? hiddenConversationIds,
  }) {
    return ConversationPreferencesState(
      pinnedConversationIds:
          Set.unmodifiable(pinnedConversationIds ?? this.pinnedConversationIds),
      groupRemarkNames:
          Map.unmodifiable(groupRemarkNames ?? this.groupRemarkNames),
      groupAvatarMemberOrders: Map.unmodifiable(
        groupAvatarMemberOrders ?? this.groupAvatarMemberOrders,
      ),
      mutedConversationIds:
          Set.unmodifiable(mutedConversationIds ?? this.mutedConversationIds),
      hiddenConversationIds:
          Set.unmodifiable(hiddenConversationIds ?? this.hiddenConversationIds),
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

final groupAvatarMemberOrdersProvider =
    Provider<Map<String, List<String>>>((ref) {
  return ref.watch(conversationPreferencesProvider).groupAvatarMemberOrders;
});

final mutedConversationIdsProvider = Provider<Set<String>>((ref) {
  return ref.watch(conversationPreferencesProvider).mutedConversationIds;
});

final hiddenConversationIdsProvider = Provider<Set<String>>((ref) {
  return ref.watch(conversationPreferencesProvider).hiddenConversationIds;
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
        groupAvatarMemberOrders: data.groupAvatarMemberOrders,
        mutedConversationIds: data.mutedConversationIds,
        hiddenConversationIds: data.hiddenConversationIds,
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

  void setGroupAvatarMemberOrder(String roomId, List<String> memberIds) {
    final trimmedRoomId = roomId.trim();
    if (trimmedRoomId.isEmpty) return;
    final nextOrder = memberIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final current = state.groupAvatarMemberOrders[trimmedRoomId] ?? const [];
    if (_sameStringList(current, nextOrder)) return;
    final next = Map<String, List<String>>.from(state.groupAvatarMemberOrders);
    if (nextOrder.isEmpty) {
      next.remove(trimmedRoomId);
    } else {
      next[trimmedRoomId] = List.unmodifiable(nextOrder);
    }
    state = state.copyWith(groupAvatarMemberOrders: next);
    _persist();
  }

  void setMuted(String conversationId, bool muted) {
    final trimmed = conversationId.trim();
    if (trimmed.isEmpty) return;
    final next = {...state.mutedConversationIds};
    if (muted) {
      next.add(trimmed);
    } else {
      next.remove(trimmed);
    }
    state = state.copyWith(mutedConversationIds: next);
    _persist();
  }

  void setHidden(String conversationId, bool hidden) {
    final trimmed = conversationId.trim();
    if (trimmed.isEmpty) return;
    final next = {...state.hiddenConversationIds};
    if (hidden) {
      next.add(trimmed);
    } else {
      next.remove(trimmed);
    }
    state = state.copyWith(hiddenConversationIds: next);
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
                groupAvatarMemberOrders: state.groupAvatarMemberOrders,
                mutedConversationIds: state.mutedConversationIds,
                hiddenConversationIds: state.hiddenConversationIds,
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

void setGroupAvatarMemberOrder(
  WidgetRef ref,
  String roomId,
  List<String> memberIds,
) {
  ref
      .read(conversationPreferencesProvider.notifier)
      .setGroupAvatarMemberOrder(roomId, memberIds);
}

void setConversationMuted(WidgetRef ref, String conversationId, bool muted) {
  ref
      .read(conversationPreferencesProvider.notifier)
      .setMuted(conversationId, muted);
}

void setConversationHidden(WidgetRef ref, String conversationId, bool hidden) {
  ref
      .read(conversationPreferencesProvider.notifier)
      .setHidden(conversationId, hidden);
}

bool _sameStringList(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
