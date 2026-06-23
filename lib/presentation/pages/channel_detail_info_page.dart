import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../channel/channel_info_data.dart';
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

class ChannelDetailInfoPage extends ConsumerStatefulWidget {
  const ChannelDetailInfoPage({
    super.key,
    required this.channelId,
    this.sharePayload,
    this.showJoinButton = false,
  });

  final String channelId;
  final ChannelSharePayload? sharePayload;
  final bool showJoinButton;

  @override
  ConsumerState<ChannelDetailInfoPage> createState() =>
      _ChannelDetailInfoPageState();
}

class _ChannelDetailInfoPageState extends ConsumerState<ChannelDetailInfoPage> {
  bool _joining = false;
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
    final fallbackChannel = widget.sharePayload == null
        ? resolveChannelInfoData(ref, widget.channelId)
        : channelInfoDataFromSharePayload(widget.sharePayload!);
    final detailFuture = _publicDetailFuture;
    if (detailFuture != null) {
      return FutureBuilder<ChannelInfoData>(
        future: detailFuture,
        builder: (context, snapshot) {
          return _buildScaffold(snapshot.data ?? fallbackChannel);
        },
      );
    }
    return _buildScaffold(fallbackChannel);
  }

  Widget _buildScaffold(ChannelInfoData channel) {
    final avatarUrl = avatarHttpUrl(
      ref.watch(matrixClientProvider),
      channel.avatarUrl,
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
                widget.showJoinButton ? 120 : 32,
              ),
              children: [
                _DetailTopBar(onBack: () => context.pop()),
                const SizedBox(height: 24),
                Center(
                  child: PortalAvatar(
                    seed: channel.name,
                    size: 86,
                    imageUrl: avatarUrl,
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
                      _ChannelTypeBadge(label: _channelTypeLabel(channel)),
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
                const SizedBox(height: 26),
                Text(
                  '频道介绍',
                  style: AppTheme.sans(
                    size: 18,
                    weight: FontWeight.w600,
                    color: context.tk.text,
                  ).copyWith(height: 33 / 18),
                ),
                const SizedBox(height: 5),
                _IntroCard(text: _channelDescription(channel)),
                if (!widget.showJoinButton) ...[
                  const SizedBox(height: 16),
                  _ShareChannelButton(
                    onTap: () => _shareChannelDetail(context, ref, channel),
                  ),
                ],
              ],
            ),
            if (widget.showJoinButton)
              Positioned(
                left: 16,
                right: 16,
                bottom: 40,
                height: 50,
                child: _JoinButton(
                  joining: _joining,
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
    final roomId = sharePayload?.roomId.trim() ??
        (_looksLikeMatrixRoomId(widget.channelId)
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

  Future<void> _joinChannel(ChannelInfoData channel) async {
    if (_joining) return;
    final channelId = channel.id.trim();
    final roomId = channel.roomId.trim();
    if (roomId.isEmpty && channelId.isEmpty) return;
    setState(() => _joining = true);
    try {
      final sharePayload = widget.sharePayload;
      final joined = sharePayload == null
          ? await ref.read(asClientProvider).joinChannelByRoomId(
                roomId.isEmpty ? channelId : roomId,
                remoteNodeBaseUri: publicBaseUriForMatrixRoomId(
                  roomId.isEmpty ? channelId : roomId,
                ),
              )
          : await ref.read(asClientProvider).joinChannel(
                channelId.isEmpty ? roomId : channelId,
                roomId: roomId,
                grantId: sharePayload.grantId,
                shareRoomId: sharePayload.shareRoomId,
                discoveredChannel: sharePayload.asDiscoveredChannel,
              );
      if (isAsChannelMemberJoined(joined.memberStatus)) {
        final bootstrap =
            await ref.read(asBootstrapRepositoryProvider).refresh();
        ref.read(asSyncCacheProvider.notifier).update(
              (state) => state.copyWith(bootstrap: bootstrap),
            );
      }
      if (!mounted) return;
      setState(() => _joining = false);
      if (isAsChannelMemberAwaitingJoin(joined.memberStatus)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_channelJoinWaitingText(joined.memberStatus))),
        );
        return;
      }
      if (isAsChannelMemberJoinFailed(joined.memberStatus)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(channelJoinStatusText(joined.memberStatus))),
        );
        return;
      }
      if (!isAsChannelMemberJoined(joined.memberStatus)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(channelJoinInProgressText)),
        );
        return;
      }
      final joinedChannelId =
          joined.channelId.trim().isEmpty ? channelId : joined.channelId.trim();
      final encodedChannelId = Uri.encodeComponent(joinedChannelId);
      if (_channelInfoIsPostType(channel)) {
        context.push('/channel/$encodedChannelId');
        return;
      }
      final route = productConversationRoute(
            joined.productConversation,
            channelId: joinedChannelId,
          ) ??
          joinedTextChannelConversationRoute(
            channelId: joinedChannelId,
            roomId: joined.roomId.trim().isEmpty ? roomId : joined.roomId,
            memberStatus: joined.memberStatus,
            channelType: joined.channelType,
            name: joined.name.trim().isEmpty ? channel.name : joined.name,
          );
      if (route == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('频道正在同步，请稍后重试')),
        );
        return;
      }
      context.push(route);
    } catch (err) {
      if (!mounted) return;
      setState(() => _joining = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加入频道失败：$err')),
      );
    }
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
      ),
      currentRoomId: channel.roomId,
      currentRoomName: channel.name,
    );
    if (!context.mounted || !sent) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已分享频道')),
    );
  } catch (err) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('分享频道失败：$err')),
    );
  }
}

String _channelJoinWaitingText(String status) {
  return channelJoinStatusText(status);
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
            '频道详情',
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
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('已复制频道 ID')),
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
                '分享频道',
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
    required this.onTap,
  });

  final bool joining;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: joining ? null : onTap,
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
              '申请加入',
              style: AppTheme.sans(
                size: 16,
                weight: FontWeight.w500,
                color: context.tk.onAccent,
              ).copyWith(height: 1),
            ),
    );
  }
}

String _channelDescription(ChannelInfoData channel) {
  final description = channel.description.trim();
  if (description.isNotEmpty && description != '暂无频道内容') {
    return description;
  }
  return '暂无频道介绍';
}

String _channelDetailDisplayId(ChannelInfoData channel) {
  final roomId = channel.roomId.trim();
  if (roomId.isNotEmpty) return roomId;
  return channel.id.trim();
}

String _channelTypeLabel(ChannelInfoData channel) {
  return _channelInfoIsPostType(channel) ? '帖子' : '文字';
}

bool _channelInfoIsPostType(ChannelInfoData channel) {
  if (channel.tags.any(_channelTagIsChatType)) return false;
  if (normalizeAsChannelType(channel.channelType) == asChannelTypePost) {
    return true;
  }
  return channel.tags
      .any((tag) => normalizeAsChannelType(tag) == asChannelTypePost);
}

bool _channelTagIsChatType(String tag) {
  final trimmed = tag.trim().toLowerCase();
  return trimmed == '文字' ||
      trimmed == 'text' ||
      normalizeAsChannelType(trimmed) == asChannelTypeChat;
}
