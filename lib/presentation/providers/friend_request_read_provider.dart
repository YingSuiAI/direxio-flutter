import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/friend_request_read_store.dart';

class FriendRequestReadState {
  const FriendRequestReadState({
    this.loaded = false,
    this.readRoomIds = const {},
  });

  final bool loaded;
  final Set<String> readRoomIds;

  int unreadCountForRoomIds(Iterable<String> roomIds) {
    var count = 0;
    for (final roomId in roomIds) {
      final trimmed = roomId.trim();
      if (trimmed.isNotEmpty && !readRoomIds.contains(trimmed)) {
        count++;
      }
    }
    return count;
  }

  FriendRequestReadState copyWith({
    bool? loaded,
    Set<String>? readRoomIds,
  }) {
    return FriendRequestReadState(
      loaded: loaded ?? this.loaded,
      readRoomIds: Set.unmodifiable(readRoomIds ?? this.readRoomIds),
    );
  }
}

class FriendRequestReadNotifier extends StateNotifier<FriendRequestReadState> {
  FriendRequestReadNotifier(this._loadStore)
      : super(const FriendRequestReadState()) {
    unawaited(_load());
  }

  final Future<FriendRequestReadStore> Function() _loadStore;

  Future<void> _load() async {
    try {
      final store = await _loadStore();
      final stored = await store.readRoomIds();
      state = FriendRequestReadState(
        loaded: true,
        readRoomIds: Set.unmodifiable({...stored, ...state.readRoomIds}),
      );
    } catch (_) {
      state = state.copyWith(loaded: true);
    }
  }

  void markRead(Iterable<String> roomIds) {
    final ids = roomIds.map((id) => id.trim()).where((id) => id.isNotEmpty);
    final next = {...state.readRoomIds, ...ids};
    if (next.length == state.readRoomIds.length && state.loaded) return;
    state = FriendRequestReadState(
      loaded: true,
      readRoomIds: Set.unmodifiable(next),
    );
    unawaited(_persist(next));
  }

  Future<void> _persist(Set<String> roomIds) async {
    try {
      final store = await _loadStore();
      await store.writeRoomIds(roomIds);
    } catch (_) {
      // Read receipts for friend-request notifications are best-effort local UI
      // state; failure must not block viewing or handling the request.
    }
  }
}

final friendRequestReadStoreProvider =
    FutureProvider<FriendRequestReadStore>((ref) async {
  final dir = await getApplicationSupportDirectory();
  return FileFriendRequestReadStore(
    File('${dir.path}/portal_im_friend_request_read.json'),
  );
});

final friendRequestReadProvider =
    StateNotifierProvider<FriendRequestReadNotifier, FriendRequestReadState>(
        (ref) {
  return FriendRequestReadNotifier(
    () => ref.read(friendRequestReadStoreProvider.future),
  );
});
