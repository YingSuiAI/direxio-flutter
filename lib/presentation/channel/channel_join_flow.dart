import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/as_client.dart';
import '../providers/as_bootstrap_store_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import 'channel_join_debug_log.dart';

const channelJoinInProgressText = '正在加入频道，加入完成后会自动打开';
const channelJoinPendingText = '申请已提交，等待频道主审核';
const channelJoinApprovedText = '申请已通过，正在同步加入频道';
const channelJoinFailedText = '加入频道失败，请稍后重试';
const _missingInviteGrantMessage = 'channel invite grant is missing or expired';
const _missingInviteGrantMessageCompact =
    'channelinvitegrantismissingorexpired';

String channelJoinStatusText(String status) {
  final normalized = status.trim().toLowerCase();
  return switch (normalized) {
    asChannelMemberStatusPending => channelJoinPendingText,
    asChannelMemberStatusApproved ||
    asChannelMemberStatusJoining =>
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
  String debugSource = '',
}) async {
  final channel = await waitForJoinedChannelProjectionData(
    ref,
    channelId: channelId,
    roomId: roomId,
    timeout: timeout,
    interval: interval,
    debugSource: debugSource,
  );
  return channel != null;
}

Future<AsChannel?> waitForJoinedChannelProjectionData(
  WidgetRef ref, {
  required String channelId,
  required String roomId,
  Duration timeout = const Duration(seconds: 12),
  Duration interval = const Duration(seconds: 2),
  String debugSource = '',
}) async {
  final deadline = DateTime.now().add(timeout);
  var attempt = 0;
  while (DateTime.now().isBefore(deadline)) {
    attempt += 1;
    final AsSyncBootstrap bootstrap;
    try {
      bootstrap = await ref.read(asBootstrapRepositoryProvider).refresh();
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.copyWith(bootstrap: bootstrap),
          );
    } catch (error) {
      if (debugSource.trim().isNotEmpty) {
        logChannelJoinProjection(
          source: debugSource,
          channelId: channelId,
          roomId: roomId,
          attempt: attempt,
          result: 'refresh_error',
          error: error,
        );
      }
      return null;
    }
    final projected = _joinedChannelFromBootstrap(
      bootstrap,
      channelId: channelId,
      roomId: roomId,
    );
    if (debugSource.trim().isNotEmpty) {
      logChannelJoinProjection(
        source: debugSource,
        channelId: channelId,
        roomId: roomId,
        attempt: attempt,
        result: projected == null ? 'not_joined' : 'joined',
        channel: projected,
      );
    }
    if (projected != null) {
      return projected;
    }
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) break;
    await Future<void>.delayed(
      remaining < interval ? remaining : interval,
    );
  }
  if (debugSource.trim().isNotEmpty) {
    logChannelJoinProjection(
      source: debugSource,
      channelId: channelId,
      roomId: roomId,
      attempt: attempt,
      result: 'timeout',
    );
  }
  return null;
}

Future<AsChannel> joinChannelWithInviteProjectionRetry(
  WidgetRef ref,
  Future<AsChannel> Function() join, {
  int retries = 6,
  Duration delay = const Duration(seconds: 2),
}) async {
  for (var attempt = 0;; attempt++) {
    try {
      return await join();
    } catch (error) {
      if (!_isMissingInviteGrant(error) || attempt >= retries) {
        rethrow;
      }
      await _refreshChannelInviteProjection(ref);
      if (attempt + 1 < retries) {
        await Future<void>.delayed(delay);
      }
    }
  }
}

Future<AsChannel> joinChannelShareWithInviteProjection(
  WidgetRef ref,
  Future<AsChannel> Function() join, {
  required String channelId,
  required String roomId,
  int retries = 6,
  Duration retryDelay = const Duration(seconds: 2),
  Duration projectionTimeout = const Duration(seconds: 12),
  Duration projectionInterval = const Duration(seconds: 2),
  String debugSource = '',
}) async {
  final joined = await joinChannelWithInviteProjectionRetry(
    ref,
    join,
    retries: retries,
    delay: retryDelay,
  );
  if (isAsChannelMemberJoined(joined.memberStatus) ||
      isAsChannelMemberJoinFailed(joined.memberStatus)) {
    return joined;
  }
  final projected = await waitForJoinedChannelProjectionData(
    ref,
    channelId: joined.channelId.trim().isEmpty
        ? channelId.trim()
        : joined.channelId.trim(),
    roomId: joined.roomId.trim().isEmpty ? roomId.trim() : joined.roomId.trim(),
    timeout: projectionTimeout,
    interval: projectionInterval,
    debugSource: debugSource,
  );
  return projected ?? joined;
}

bool _isMissingInviteGrant(Object error) {
  final message = error is AsClientException ? error.message.toLowerCase() : '';
  final compactMessage = message.replaceAll(RegExp(r'\s+'), '');
  return error is AsClientException &&
      error.statusCode == 403 &&
      (message.contains(_missingInviteGrantMessage) ||
          compactMessage.contains(_missingInviteGrantMessageCompact));
}

Future<void> _refreshChannelInviteProjection(WidgetRef ref) async {
  try {
    final matrixClient = ref.read(matrixClientProvider);
    if (matrixClient.isLogged()) {
      await matrixClient.oneShotSync();
    }
  } catch (_) {
    // Best effort: AS bootstrap may already have projected the Matrix invite.
  }
  try {
    final bootstrap = await ref.read(asBootstrapRepositoryProvider).refresh();
    ref.read(asSyncCacheProvider.notifier).update(
          (state) => state.copyWith(bootstrap: bootstrap),
        );
  } catch (_) {
    // The next join attempt will surface the original server-side state.
  }
}

AsChannel? _joinedChannelFromBootstrap(
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
      return _channelFromBootstrapSummary(channel);
    }
  }
  return null;
}

AsChannel _channelFromBootstrapSummary(AsSyncRoomSummary summary) {
  return AsChannel(
    channelId: summary.channelId,
    roomId: summary.roomId,
    homeDomain: summary.homeDomain,
    name: summary.name,
    description: summary.description,
    avatarUrl: summary.avatarUrl,
    visibility: summary.visibility,
    joinPolicy: summary.joinPolicy,
    commentsEnabled: summary.commentsEnabled,
    muted: summary.muted,
    channelType: summary.channelType,
    role: summary.role,
    memberStatus: summary.memberStatus,
    lifecycle: summary.lifecycle,
    memberCount: summary.memberCount,
    pendingJoinCount: summary.pendingJoinCount,
    tags: summary.tags,
    latestActivityAt: summary.lastActivityAt,
  );
}
