import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/as_client.dart';
import '../../l10n/app_localizations.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/block_list_provider.dart';
import 'center_toast.dart';

enum BlockedRouteTargetKind { room, contact }

class BlockedRouteGuard extends ConsumerStatefulWidget {
  const BlockedRouteGuard({
    super.key,
    required this.kind,
    required this.child,
    this.roomId,
    this.peerMxid,
    this.fallbackLocation = '/home',
  });

  final BlockedRouteTargetKind kind;
  final Widget child;
  final String? roomId;
  final String? peerMxid;
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
        oldWidget.peerMxid != widget.peerMxid) {
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
}) {
  final room = roomId?.trim() ?? '';
  final peer = peerMxid?.trim() ?? '';
  return switch (kind) {
    BlockedRouteTargetKind.contact => isContactBlocked(
        blocks,
        peerMxid: peer.isNotEmpty
            ? peer
            : syncCache.acceptedContactForRoom(room)?.userId ?? '',
        roomId: room,
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
  );
}
