import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/as_client.dart';
import '../providers/as_bootstrap_store_provider.dart';
import '../providers/as_sync_cache_provider.dart';

const channelJoinInProgressText = '正在加入频道，加入完成后会自动打开';
const channelJoinPendingText = '申请已提交，等待频道主审核';
const channelJoinApprovedText = '申请已通过，正在同步加入频道';
const channelJoinFailedText = '加入频道失败，请稍后重试';

String channelJoinStatusText(String status) {
  final normalized = status.trim().toLowerCase();
  return switch (normalized) {
    asChannelMemberStatusPending => channelJoinPendingText,
    asChannelMemberStatusApproved || asChannelMemberStatusJoining =>
      channelJoinApprovedText,
    asChannelMemberStatusJoinFailed => channelJoinFailedText,
    _ => channelJoinInProgressText,
  };
}

Future<bool> waitForJoinedChannelProjection(
  WidgetRef ref, {
  required String channelId,
  required String roomId,
  Duration timeout = const Duration(seconds: 12),
  Duration interval = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final AsSyncBootstrap bootstrap;
    try {
      bootstrap = await ref.read(asBootstrapRepositoryProvider).refresh();
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.copyWith(bootstrap: bootstrap),
          );
    } catch (_) {
      return false;
    }
    if (_bootstrapHasJoinedChannel(
      bootstrap,
      channelId: channelId,
      roomId: roomId,
    )) {
      return true;
    }
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) break;
    await Future<void>.delayed(
      remaining < interval ? remaining : interval,
    );
  }
  return false;
}

bool _bootstrapHasJoinedChannel(
  AsSyncBootstrap bootstrap, {
  required String channelId,
  required String roomId,
}) {
  final cleanChannelId = channelId.trim();
  final cleanRoomId = roomId.trim();
  for (final channel in bootstrap.channels) {
    final idMatches =
        cleanChannelId.isNotEmpty && channel.channelId.trim() == cleanChannelId;
    final roomMatches =
        cleanRoomId.isNotEmpty && channel.roomId.trim() == cleanRoomId;
    if ((idMatches || roomMatches) &&
        isAsChannelMemberJoined(channel.memberStatus)) {
      return true;
    }
  }
  return false;
}
