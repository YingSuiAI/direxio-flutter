import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../../l10n/app_localizations.dart';
import '../channel/channel_avatar_cache.dart';
import '../channel/channel_info_data.dart';
import '../channel/channel_join_debug_log.dart';
import '../channel/channel_join_flow.dart';
import '../channel/channel_share.dart';
import '../channel/public_channel_target.dart';
import '../providers/as_bootstrap_store_provider.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/avatar_url.dart';
import '../utils/product_conversation_navigation.dart';
import '../widgets/m3/glass_header.dart';
import '../widgets/portal_avatar.dart';
import '../widgets/center_toast.dart';

class ChannelDetailInfoPage extends ConsumerStatefulWidget {
  const ChannelDetailInfoPage({
    super.key,
    required this.channelId,
    this.routeRoomId,
    this.routeName,
    this.routeAvatarUrl,
    this.routeDescription,
    this.routeChannelType,
    this.sharePayload,
    this.showJoinButton = false,
  });

  final String channelId;
  final String? routeRoomId;
  final String? routeName;
  final String? routeAvatarUrl;
  final String? routeDescription;
  final String? routeChannelType;
  final ChannelSharePayload? sharePayload;
  final bool showJoinButton;

  @override
  ConsumerState<ChannelDetailInfoPage> createState() =>
      _ChannelDetailInfoPageState();
}

class _ChannelDetailInfoPageState extends ConsumerState<ChannelDetailInfoPage> {
  bool _joining = false;
  bool _requested = false;
  Future<ChannelInfoData>? _publicDetailFuture;

  @override
  void initState() {
    super.initState();
    _publicDetailFuture = _loadPublicDetail();
  }

  @override
  void didUpdateWidget(covariant ChannelDetailInfoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channelId == widget.channelId &&
        oldWidget.sharePayload == widget.sharePayload) {
      return;
    }
    _publicDetailFuture = _loadPublicDetail();
  }

  @override
  Widget build(BuildContext context) {
    final fallbackChannel = _resolveFallbackChannel();
    final detailFuture = _publicDetailFuture;
    if (detailFuture != null) {
      return FutureBuilder<ChannelInfoData>(
        future: detailFuture,
        builder: (context, snapshot) {
          final channel = snapshot.data == null
              ? fallbackChannel
              : mergeChannelInfoDataForDetail(fallbackChannel, snapshot.data!);
          return _buildScaffold(channel);
        },
      );
    }
    return _buildScaffold(fallbackChannel);
  }

  ChannelInfoData _resolveFallbackChannel() {
    final localChannel = _mergeRouteChannelFallback(
      resolveChannelInfoData(ref, widget.channelId),
    );
    final sharePayload = widget.sharePayload;
    if (sharePayload == null) return localChannel;
    return _withLocalChannelState(
      channelInfoDataFromSharePayload(sharePayload),
      localChannel,
    );
  }

  Widget _buildScaffold(ChannelInfoData channel) {
    final showJoinButton =
        widget.showJoinButton && !_channelInfoAlreadyJoinedOrOwned(channel);
    final avatarUrl = avatarHttpUrl(
      ref.watch(matrixClientProvider),
      channel.avatarUrl,
    );
    final avatarStableKey = channelAvatarStableCacheKey(
      channelId: channel.id,
      roomId: channel.roomId,
    );
    return Scaffold(
      backgroundColor: context.tk.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                showJoinButton ? 120 : 32,
              ),
              children: [
                _DetailTopBar(onBack: () => context.pop()),
                const SizedBox(height: 24),
                Center(
                  child: PortalAvatar(
                    seed: channel.name,
                    size: 86,
                    imageUrl: avatarUrl,
                    stableCacheKey: avatarStableKey,
                    shape: AvatarShape.squircle,
                  ),
                ),
                const SizedBox(height: 15),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        channelDisplayNameWithMemberCount(channel),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.sans(
                          size: 15,
                          weight: FontWeight.w600,
                          color: context.tk.textMute,
                        ).copyWith(height: 33 / 15),
                      ),
                      const SizedBox(width: 4),
                      _ChannelTypeBadge(
                        label: _channelTypeLabel(context, channel),
                      ),
                    ],
                  ),
                ),
                if (_channelDetailDisplayId(channel).isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Center(
                    child: _ChannelIdRow(
                      channelId: _channelDetailDisplayId(channel),
                    ),
                  ),
                ],
                if (_channelInfoRatingLabel(channel) != null) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: _ChannelRatingPill(
                      label: _channelInfoRatingLabel(channel)!,
                    ),
                  ),
                ],
                const SizedBox(height: 26),
                Text(
                  _channelInfoL10n(context)?.channelDetailIntroTitle ?? '频道介绍',
                  style: AppTheme.sans(
                    size: 18,
                    weight: FontWeight.w600,
                    color: context.tk.text,
                  ).copyWith(height: 33 / 18),
                ),
                const SizedBox(height: 5),
                _IntroCard(text: _channelDescription(context, channel)),
                if (!showJoinButton) ...[
                  const SizedBox(height: 16),
                  _ShareChannelButton(
                    onTap: () => _shareChannelDetail(context, ref, channel),
                  ),
                ],
              ],
            ),
            if (showJoinButton)
              Positioned(
                left: 16,
                right: 16,
                bottom: 40,
                height: 50,
                child: _JoinButton(
                  joining: _joining,
                  requested: _requested ||
                      isAsChannelMemberAwaitingJoin(channel.memberStatus),
                  onTap: () => _joinChannel(channel),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<ChannelInfoData>? _loadPublicDetail() {
    final sharePayload = widget.sharePayload;
    if (sharePayload != null &&
        sharePayload.visibility.trim() == asChannelVisibilityPrivate) {
      return Future.value(channelInfoDataFromSharePayload(sharePayload));
    }
    final routeRoomId = widget.routeRoomId?.trim() ?? '';
    final roomId = sharePayload?.roomId.trim() ??
        (routeRoomId.isNotEmpty
            ? routeRoomId
            : _looksLikeMatrixRoomId(widget.channelId)
                ? widget.channelId.trim()
                : '');
    if (roomId.isEmpty) return null;
    return ref
        .read(asClientProvider)
        .getPublicChannelByRoomId(
          roomId,
          remoteNodeBaseUri: publicBaseUriForMatrixRoomId(roomId),
        )
        .then(channelInfoDataFromAsChannel);
  }

  ChannelInfoData _mergeRouteChannelFallback(ChannelInfoData fallback) {
    final routeRoomId = widget.routeRoomId?.trim() ?? '';
    final routeName = widget.routeName?.trim() ?? '';
    final routeAvatarUrl = widget.routeAvatarUrl?.trim() ?? '';
    final routeDescription = widget.routeDescription?.trim() ?? '';
    final routeChannelType = widget.routeChannelType?.trim() ?? '';
    if (routeRoomId.isEmpty &&
        routeName.isEmpty &&
        routeAvatarUrl.isEmpty &&
        routeDescription.isEmpty &&
        routeChannelType.isEmpty) {
      return fallback;
    }
    return ChannelInfoData(
      id: fallback.id,
      roomId: routeRoomId.isNotEmpty ? routeRoomId : fallback.roomId,
      domain: fallback.domain,
      name: routeName.isNotEmpty ? routeName : fallback.name,
      avatarUrl:
          routeAvatarUrl.isNotEmpty ? routeAvatarUrl : fallback.avatarUrl,
      description:
          routeDescription.isNotEmpty ? routeDescription : fallback.description,
      visibility: fallback.visibility,
      joinPolicy: fallback.joinPolicy,
      memberStatus: fallback.memberStatus,
      isOwned: fallback.isOwned,
      commentsEnabled: fallback.commentsEnabled,
      muted: fallback.muted,
      channelType:
          routeChannelType.isNotEmpty ? routeChannelType : fallback.channelType,
      tags: fallback.tags,
      memberCount: fallback.memberCount,
      ratingCount: fallback.ratingCount,
      averageScore: fallback.averageScore,
    );
  }

  Future<void> _joinChannel(ChannelInfoData channel) async {
    if (_joining) return;
    final channelId = channel.id.trim();
    final roomId = channel.roomId.trim();
    if (roomId.isEmpty && channelId.isEmpty) return;
    setState(() => _joining = true);
    try {
      final sharePayload = widget.sharePayload;
      if (sharePayload != null) {
        logChannelShareJoinStart(
          source: 'channel_detail_share',
          payload: sharePayload,
          action: channelShareHasInviteGrant(sharePayload)
              ? 'channels.join'
              : 'channels.public.join_request',
          targetId: channelShareHasInviteGrant(sharePayload)
              ? (channelId.isEmpty ? roomId : channelId)
              : channelShareJoinRequestTargetId(sharePayload),
        );
      }
      final joined = sharePayload == null
          ? await ref.read(asClientProvider).joinChannelByRoomId(
                roomId.isEmpty ? channelId : roomId,
                remoteNodeBaseUri: publicBaseUriForMatrixRoomId(
                  roomId.isEmpty ? channelId : roomId,
                ),
              )
          : channelShareHasInviteGrant(sharePayload)
              ? await joinChannelShareWithInviteProjection(
                  ref,
                  () => ref.read(asClientProvider).joinChannel(
                        channelId.isEmpty ? roomId : channelId,
                        roomId: roomId,
                        grantId: sharePayload.grantId,
                        shareRoomId: sharePayload.shareRoomId,
                        discoveredChannel: sharePayload.asDiscoveredChannel,
                      ),
                  channelId: channelId,
                  roomId: roomId,
                  debugSource: 'channel_detail_share',
                )
              : await ref.read(asClientProvider).joinChannelByRoomId(
                    channelShareJoinRequestTargetId(sharePayload),
                    discoveredChannel: sharePayload.asDiscoveredChannel,
                    remoteNodeBaseUri: publicBaseUriForMatrixRoomId(roomId),
                  );
      if (sharePayload != null) {
        logChannelShareJoinResult(
          source: 'channel_detail_share',
          payload: sharePayload,
          channel: joined,
          stage: isAsChannelMemberJoined(joined.memberStatus)
              ? 'joined_or_projected'
              : 'waiting',
        );
      }
      if (!mounted) return;
      if (isAsChannelMemberJoinFailed(joined.memberStatus)) {
        setState(() => _joining = false);
        showTopSnackBar(
          context,
          SnackBar(
            content: Text(
              channelJoinStatusText(
                joined.memberStatus,
                l10n: _channelInfoL10n(context),
              ),
            ),
          ),
        );
        return;
      }
      if (!isAsChannelMemberJoined(joined.memberStatus)) {
        setState(() => _requested = true);
        showTopSnackBar(
          context,
          SnackBar(
            content:
                Text(_channelJoinWaitingText(context, joined.memberStatus)),
          ),
        );
        if (sharePayload != null && !channelShareHasInviteGrant(sharePayload)) {
          setState(() => _joining = false);
          return;
        }
        final projected = await waitForJoinedChannelProjectionData(
          ref,
          channelId: joined.channelId.trim().isEmpty
              ? channelId
              : joined.channelId.trim(),
          roomId: joined.roomId.trim().isEmpty ? roomId : joined.roomId.trim(),
          debugSource: sharePayload == null
              ? 'channel_detail_public'
              : 'channel_detail_share',
        );
        if (!mounted) return;
        setState(() => _joining = false);
        if (projected == null) return;
        _openJoinedChannel(projected, fallback: channel);
        return;
      }
      setState(() => _joining = false);
      final bootstrap = await ref.read(asBootstrapRepositoryProvider).refresh();
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.copyWith(bootstrap: bootstrap),
          );
      if (!mounted) return;
      _openJoinedChannel(joined, fallback: channel);
    } catch (err) {
      final sharePayload = widget.sharePayload;
      if (sharePayload != null) {
        logChannelShareJoinError(
          err,
          source: 'channel_detail_share',
          payload: sharePayload,
        );
      }
      logChannelJoinForbidden(
        err,
        source: sharePayload == null
            ? 'channel_detail_public'
            : 'channel_detail_share',
        channelId: channelId,
        roomId: roomId,
        grantId: sharePayload?.grantId ?? '',
        shareRoomId: sharePayload?.shareRoomId ?? '',
        remoteNodeBaseUri: sharePayload == null
            ? publicBaseUriForMatrixRoomId(roomId.isEmpty ? channelId : roomId)
            : null,
        discoveredChannel: sharePayload?.asDiscoveredChannel,
      );
      if (!mounted) return;
      setState(() => _joining = false);
      showTopSnackBar(
        context,
        SnackBar(
          content: Text(
            _channelInfoL10n(context)?.channelJoinFailed('$err') ??
                '加入频道失败：$err',
          ),
        ),
      );
    }
  }

  void _openJoinedChannel(
    AsChannel joined, {
    required ChannelInfoData fallback,
  }) {
    final channelId = joined.channelId.trim().isEmpty
        ? fallback.id.trim()
        : joined.channelId.trim();
    final encodedChannelId = Uri.encodeComponent(
      channelId.isEmpty ? fallback.roomId.trim() : channelId,
    );
    if (_joinedChannelIsPostType(joined, fallback)) {
      context.push('/channel/$encodedChannelId');
      return;
    }
    final route = productConversationRoute(
          joined.productConversation,
          channelId: channelId,
        ) ??
        joinedTextChannelConversationRoute(
          channelId: channelId,
          roomId: joined.roomId.trim().isEmpty
              ? fallback.roomId.trim()
              : joined.roomId.trim(),
          memberStatus: asChannelMemberStatusJoined,
          channelType: joined.channelType.trim().isEmpty
              ? fallback.channelType
              : joined.channelType,
          name: joined.name.trim().isEmpty ? fallback.name : joined.name,
        ) ??
        channelConversationRoute(
          channelId,
          name: joined.name.trim().isEmpty ? fallback.name : joined.name,
        );
    context.push(route);
  }
}

Future<void> _shareChannelDetail(
  BuildContext context,
  WidgetRef ref,
  ChannelInfoData channel,
) async {
  try {
    final sent = await showAndShareChannel(
      context,
      ref,
      payload: channelSharePayloadFromChannel(
        channelId: channel.id,
        roomId: channel.roomId,
        homeDomain: channel.domain,
        name: channel.name,
        description: channel.description,
        avatarUrl: channel.avatarUrl,
        visibility: channel.visibility,
        joinPolicy: channel.joinPolicy,
        commentsEnabled: channel.commentsEnabled,
        channelType: channel.channelType,
        tags: channel.tags,
        memberCount: channel.memberCount,
        ratingCount: channel.ratingCount,
        averageScore: channel.averageScore,
      ),
      currentRoomId: channel.roomId,
      currentRoomName: channel.name,
    );
    if (!context.mounted || !sent) return;
    final l10n = _channelInfoL10n(context);
    showTopSnackBar(
      context,
      SnackBar(content: Text(l10n?.channelInfoShared ?? '已分享频道')),
    );
  } catch (err) {
    if (!context.mounted) return;
    final l10n = _channelInfoL10n(context);
    showTopSnackBar(
      context,
      SnackBar(
        content: Text(
          l10n?.channelInfoShareFailed('$err') ?? '分享频道失败：$err',
        ),
      ),
    );
  }
}

String _channelJoinWaitingText(BuildContext context, String status) {
  return channelJoinStatusText(status, l10n: _channelInfoL10n(context));
}

bool _channelInfoAlreadyJoinedOrOwned(ChannelInfoData channel) {
  return channel.isOwned || isAsChannelMemberJoined(channel.memberStatus);
}

ChannelInfoData _withLocalChannelState(
  ChannelInfoData display,
  ChannelInfoData local,
) {
  return ChannelInfoData(
    id: display.id,
    roomId: display.roomId,
    domain: display.domain,
    name: display.name,
    avatarUrl: display.avatarUrl,
    description: display.description,
    visibility: display.visibility,
    joinPolicy: display.joinPolicy,
    memberStatus:
        _preferChannelInfoText(local.memberStatus, display.memberStatus),
    isOwned: display.isOwned || local.isOwned,
    commentsEnabled: display.commentsEnabled,
    muted: display.muted || local.muted,
    channelType: display.channelType,
    tags: display.tags,
    memberCount: display.memberCount,
    ratingCount: display.ratingCount,
    averageScore: display.averageScore,
  );
}

String _preferChannelInfoText(String primary, String fallback) {
  final first = primary.trim();
  if (first.isNotEmpty) return first;
  return fallback.trim();
}

bool _looksLikeMatrixRoomId(String value) {
  return value.trim().startsWith('!') && value.contains(':');
}

class _ChannelIdRow extends StatelessWidget {
  const _ChannelIdRow({required this.channelId});

  final String channelId;

  @override
  Widget build(BuildContext context) {
    final id = channelId.trim();
    return InkWell(
      onTap: () => _copyChannelId(context, id),
      borderRadius: BorderRadius.circular(6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              'ID:$id',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.sans(
                size: 13,
                color: context.tk.textMute,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Symbols.content_copy,
            size: 14,
            color: context.tk.textMute,
          ),
        ],
      ),
    );
  }
}

class _DetailTopBar extends StatelessWidget {
  const _DetailTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            top: 4,
            child: GlassHeaderButton(
              icon: Symbols.arrow_back,
              iconSize: 22,
              color: context.tk.text,
              onTap: onBack,
            ),
          ),
          Text(
            _channelInfoL10n(context)?.channelDetailTitle ?? '频道详情',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.sans(
              size: 20,
              weight: FontWeight.w600,
              color: context.tk.text,
            ).copyWith(height: 33 / 20),
          ),
        ],
      ),
    );
  }
}

Future<void> _copyChannelId(BuildContext context, String channelId) async {
  await Clipboard.setData(ClipboardData(text: channelId));
  if (!context.mounted) return;
  showTopSnackBar(
    context,
    SnackBar(
      content: Text(
        _channelInfoL10n(context)?.channelDetailCopiedId ?? '已复制频道 ID',
      ),
    ),
  );
}

class _ChannelTypeBadge extends StatelessWidget {
  const _ChannelTypeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: 12,
        constraints: const BoxConstraints(minWidth: 21),
        padding: const EdgeInsets.symmetric(horizontal: 3),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.tk.surfaceHover,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: AppTheme.sans(
            size: 8,
            weight: FontWeight.w500,
            color: context.tk.textMute,
          ).copyWith(height: 16 / 8),
        ),
      ),
    );
  }
}

class _ChannelRatingPill extends StatelessWidget {
  const _ChannelRatingPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: context.tk.surfaceHover,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: AppTheme.sans(
          size: 13,
          weight: FontWeight.w500,
          color: context.tk.textMute,
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 89,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: context.tk.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: AppTheme.sans(
          size: 12,
          weight: FontWeight.w500,
          color: context.tk.textMute,
        ).copyWith(height: 20 / 12),
      ),
    );
  }
}

class _ShareChannelButton extends StatelessWidget {
  const _ShareChannelButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.tk.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Symbols.ios_share,
                size: 20,
                color: context.tk.text,
              ),
              const SizedBox(width: 8),
              Text(
                _channelInfoL10n(context)?.channelInfoShareAction ?? '分享频道',
                style: AppTheme.sans(
                  size: 15,
                  weight: FontWeight.w600,
                  color: context.tk.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JoinButton extends StatelessWidget {
  const _JoinButton({
    required this.joining,
    required this.requested,
    required this.onTap,
  });

  final bool joining;
  final bool requested;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: joining || requested ? null : onTap,
      style: FilledButton.styleFrom(
        fixedSize: const Size.fromHeight(50),
        backgroundColor: context.tk.accent,
        disabledBackgroundColor: context.tk.accent.withValues(alpha: 0.6),
        foregroundColor: context.tk.onAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
      ),
      child: joining
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.tk.onAccent,
              ),
            )
          : Text(
              requested
                  ? _channelInfoL10n(context)?.channelShareRequested ??
                      '已申请加入频道'
                  : _channelInfoL10n(context)?.channelJoinApply ?? '申请加入',
              style: AppTheme.sans(
                size: 16,
                weight: FontWeight.w500,
                color: context.tk.onAccent,
              ).copyWith(height: 1),
            ),
    );
  }
}

String _channelDescription(BuildContext context, ChannelInfoData channel) {
  final description = channel.description.trim();
  if (description.isNotEmpty && description != '暂无频道内容') {
    return description;
  }
  return _channelInfoL10n(context)?.channelDetailNoIntro ?? '暂无频道介绍';
}

String? _channelInfoRatingLabel(ChannelInfoData channel) {
  final score = channel.averageScore;
  final count = channel.ratingCount;
  if (score <= 0 && count <= 0) return null;
  return '★ ${score.toStringAsFixed(1)} ($count)';
}

String _channelDetailDisplayId(ChannelInfoData channel) {
  final roomId = channel.roomId.trim();
  if (roomId.isNotEmpty) return roomId;
  return channel.id.trim();
}

String _channelTypeLabel(BuildContext context, ChannelInfoData channel) {
  return _channelInfoIsPostType(channel)
      ? _channelInfoL10n(context)?.channelKindPost ?? '帖子'
      : _channelInfoL10n(context)?.channelKindText ?? '文字';
}

bool _channelInfoIsPostType(ChannelInfoData channel) {
  if (channel.tags.any(_channelTagIsChatType)) return false;
  if (normalizeAsChannelType(channel.channelType) == asChannelTypePost) {
    return true;
  }
  return channel.tags
      .any((tag) => normalizeAsChannelType(tag) == asChannelTypePost);
}

bool _joinedChannelIsPostType(
  AsChannel joined,
  ChannelInfoData fallback,
) {
  if (joined.tags.any(_channelTagIsChatType)) return false;
  final joinedType = normalizeAsChannelType(joined.channelType);
  if (joinedType == asChannelTypePost) return true;
  if (joinedType == asChannelTypeChat) return false;
  return _channelInfoIsPostType(fallback);
}

bool _channelTagIsChatType(String tag) {
  final trimmed = tag.trim().toLowerCase();
  return trimmed == '文字' ||
      trimmed == 'text' ||
      normalizeAsChannelType(trimmed) == asChannelTypeChat;
}

AppLocalizations? _channelInfoL10n(BuildContext context) {
  return Localizations.of<AppLocalizations>(context, AppLocalizations);
}
