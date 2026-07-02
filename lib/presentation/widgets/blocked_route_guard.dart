import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/as_client.dart';
import '../../l10n/app_localizations.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/block_list_provider.dart';
import 'center_toast.dart';

enum BlockedRouteTargetKind { room, contact, group, channel }

class BlockedRouteGuard extends ConsumerStatefulWidget {
  const BlockedRouteGuard({
    super.key,
    required this.kind,
    required this.child,
    this.roomId,
    this.peerMxid,
    this.channelId,
    this.fallbackLocation = '/home',
  });

  final BlockedRouteTargetKind kind;
  final Widget child;
  final String? roomId;
  final String? peerMxid;
  final String? channelId;
  final String fallbackLocation;

  @override
  ConsumerState<BlockedRouteGuard> createState() => _BlockedRouteGuardState();
}

class _BlockedRouteGuardState extends ConsumerState<BlockedRouteGuard> {
  bool _handled = false;

  @override
  void didUpdateWidget(covariant BlockedRouteGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind ||
        oldWidget.roomId != widget.roomId ||
        oldWidget.peerMxid != widget.peerMxid ||
        oldWidget.channelId != widget.channelId) {
      _handled = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocks = ref.watch(blockListProvider).valueOrNull;
    final syncCache = ref.watch(asSyncCacheProvider);
    final blocked = _routeIsBlocked(
      blocks,
      syncCache,
      kind: widget.kind,
      roomId: widget.roomId,
      peerMxid: widget.peerMxid,
      channelId: widget.channelId,
    );
    if (blocked) {
      _handleBlockedRoute(context);
      return const SizedBox.expand();
    }
    return widget.child;
  }

  void _handleBlockedRoute(BuildContext context) {
    if (_handled) return;
    _handled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !context.mounted) return;
      final l10n = Localizations.of<AppLocalizations>(
        context,
        AppLocalizations,
      );
      showTopSnackBar(
        context,
        SnackBar(
          content: Text(l10n?.blockAlreadyBlocked ?? '已经拉黑'),
        ),
      );
      context.go(widget.fallbackLocation);
    });
  }
}

bool _routeIsBlocked(
  AsBlockList? blocks,
  AsSyncCacheState syncCache, {
  required BlockedRouteTargetKind kind,
  String? roomId,
  String? peerMxid,
  String? channelId,
}) {
  final room = roomId?.trim() ?? '';
  final peer = peerMxid?.trim() ?? '';
  final channel = channelId?.trim() ?? '';
  return switch (kind) {
    BlockedRouteTargetKind.contact => isContactBlocked(
        blocks,
        peerMxid: peer.isNotEmpty
            ? peer
            : syncCache.acceptedContactForRoom(room)?.userId ?? '',
        roomId: room,
      ),
    BlockedRouteTargetKind.group => isGroupBlocked(blocks, room),
    BlockedRouteTargetKind.channel => isChannelBlocked(
        blocks,
        _resolvedChannelRoomId(syncCache, channelId: channel, roomId: room),
      ),
    BlockedRouteTargetKind.room => _roomIsBlocked(
        blocks,
        syncCache,
        roomId: room,
      ),
  };
}

bool _roomIsBlocked(
  AsBlockList? blocks,
  AsSyncCacheState syncCache, {
  required String roomId,
}) {
  final room = roomId.trim();
  if (room.isEmpty) return false;
  return isContactBlocked(
        blocks,
        peerMxid: syncCache.acceptedContactForRoom(room)?.userId ?? '',
        roomId: room,
      ) ||
      isGroupBlocked(blocks, room) ||
      isChannelBlocked(blocks, room);
}

String _resolvedChannelRoomId(
  AsSyncCacheState syncCache, {
  required String channelId,
  required String roomId,
}) {
  final room = roomId.trim();
  if (room.isNotEmpty) return room;
  final channel = channelId.trim();
  if (channel.isEmpty) return '';
  for (final item
      in syncCache.bootstrap?.channels ?? const <AsSyncRoomSummary>[]) {
    final itemRoomId = item.roomId.trim();
    if (itemRoomId.isEmpty) continue;
    if (item.channelId.trim() == channel || itemRoomId == channel) {
      return itemRoomId;
    }
  }
  return channel;
}
