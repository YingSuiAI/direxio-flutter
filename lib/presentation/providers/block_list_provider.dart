import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/as_client.dart';
import 'as_client_provider.dart';

final blockListProvider =
    StateNotifierProvider<BlockListController, AsyncValue<AsBlockList>>((ref) {
  return BlockListController(ref.read(asClientProvider));
});

class BlockListController extends StateNotifier<AsyncValue<AsBlockList>> {
  BlockListController(this._client) : super(const AsyncValue.loading()) {
    unawaited(refresh());
  }

  final AsClient _client;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_client.listBlocks);
  }

  Future<void> blockContact({
    required String peerMxid,
    String displayName = '',
    String avatarUrl = '',
  }) async {
    final item = await _client.blockContact(
      peerMxid: peerMxid,
      displayName: displayName,
      avatarUrl: avatarUrl,
    );
    state = AsyncValue.data(_upsert(state.valueOrNull, item));
  }

  Future<void> removeBlock({
    required String targetType,
    required String targetId,
  }) async {
    await _client.removeBlock(targetType: targetType, targetId: targetId);
    state = AsyncValue.data(
      _remove(state.valueOrNull, targetType: targetType, targetId: targetId),
    );
  }

  AsBlockList _upsert(AsBlockList? current, AsBlockItem item) {
    final blocks = current ?? const AsBlockList();
    return AsBlockList(contacts: _upsertItem(blocks.contacts, item));
  }

  AsBlockList _remove(
    AsBlockList? current, {
    required String targetType,
    required String targetId,
  }) {
    final blocks = current ?? const AsBlockList();
    return AsBlockList(contacts: _removeItem(blocks.contacts, targetId));
  }
}

bool isContactBlocked(
  AsBlockList? blocks, {
  required String peerMxid,
  String roomId = '',
}) {
  final peer = peerMxid.trim();
  final room = roomId.trim();
  return blocks?.contacts.any((item) {
        return (peer.isNotEmpty && item.peerMxid.trim() == peer) ||
            (room.isNotEmpty && item.roomId.trim() == room) ||
            (peer.isNotEmpty && item.targetId.trim() == peer);
      }) ??
      false;
}

List<AsBlockItem> _upsertItem(List<AsBlockItem> items, AsBlockItem item) {
  final next = [
    for (final existing in items)
      if (!_sameBlockId(existing, item.displayId)) existing,
    item,
  ];
  return List.unmodifiable(next);
}

List<AsBlockItem> _removeItem(List<AsBlockItem> items, String targetId) {
  return List.unmodifiable([
    for (final item in items)
      if (!_sameBlockId(item, targetId)) item,
  ]);
}

bool _sameBlockId(AsBlockItem item, String targetId) {
  final target = targetId.trim();
  if (target.isEmpty) return false;
  return item.targetId.trim() == target ||
      item.roomId.trim() == target ||
      item.peerMxid.trim() == target;
}
