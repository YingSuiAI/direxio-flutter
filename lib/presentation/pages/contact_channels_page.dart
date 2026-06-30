import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../../l10n/app_localizations.dart';
import '../channel/channel_avatar_cache.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/avatar_url.dart';
import '../utils/product_conversation_navigation.dart';
import '../widgets/portal_avatar.dart';

typedef _ContactPublicChannelsRequest = ({
  String userId,
  Uri? remoteNodeBaseUri,
});

final _contactPublicChannelsProvider = FutureProvider.autoDispose
    .family<List<AsChannel>, _ContactPublicChannelsRequest>((ref, request) {
  return ref.read(asClientProvider).getUserPublicChannels(
        request.userId,
        remoteNodeBaseUri: request.remoteNodeBaseUri,
      );
});

class ContactChannelsPage extends ConsumerWidget {
  const ContactChannelsPage({
    super.key,
    required this.userId,
    this.remoteNodeBaseUri,
  });

  final String userId;
  final Uri? remoteNodeBaseUri;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(asSyncCacheProvider).bootstrap;
    final channelsValue = ref.watch(
      _contactPublicChannelsProvider((
        userId: userId,
        remoteNodeBaseUri: remoteNodeBaseUri,
      )),
    );
    final t = context.tk;
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Column(
            children: [
              _ContactChannelsHeader(
                title: l10n?.contactHisChannels ?? '他的频道',
                onBack: () => context.pop(),
              ),
              Expanded(
                child: channelsValue.when(
                  loading: () => Center(
                    child: Text(
                      l10n?.contactChannelsLoading ?? '正在加载频道',
                      style: AppTheme.sans(size: 15, color: t.textMute),
                    ),
                  ),
                  error: (_, __) => Center(
                    child: Text(
                      l10n?.contactChannelsLoadFailed ?? '频道加载失败',
                      style: AppTheme.sans(size: 15, color: t.textMute),
                    ),
                  ),
                  data: (channels) => channels.isEmpty
                      ? Center(
                          child: Text(
                            l10n?.contactChannelsEmpty ?? '暂无频道',
                            style: AppTheme.sans(size: 15, color: t.textMute),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(0, 14, 0, 28),
                          children: [
                            for (var i = 0; i < channels.length; i++)
                              _ContactChannelListItem(
                                item: _ContactChannelItem.fromAsChannel(
                                  channels[i],
                                  l10n: l10n,
                                  joinedChannel: _viewerJoinedChannel(
                                    bootstrap,
                                    channels[i],
                                  ),
                                ),
                                showDivider: i != channels.length - 1,
                              ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactChannelsHeader extends StatelessWidget {
  const _ContactChannelsHeader({
    required this.title,
    required this.onBack,
  });

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: t.text.withValues(alpha: 0.12),
                    blurRadius: 36,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: ClipOval(
                child: Material(
                  color: t.surface.withValues(alpha: 0.65),
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: onBack,
                    customBorder: const CircleBorder(),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        Symbols.arrow_back,
                        size: 24,
                        color: t.text,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.sans(
              size: 20,
              weight: FontWeight.w600,
              color: t.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactChannelItem {
  const _ContactChannelItem({
    required this.channelId,
    required this.roomId,
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
    required this.tag,
    required this.channelType,
    required this.description,
    required this.joined,
  });

  factory _ContactChannelItem.fromAsChannel(
    AsChannel channel, {
    required AppLocalizations? l10n,
    required AsSyncRoomSummary? joinedChannel,
  }) {
    final title = channel.name.trim().isEmpty
        ? l10n?.contactChannelsUnnamed ?? '未命名频道'
        : channel.name.trim();
    final subtitle = channel.description.trim().isEmpty
        ? channel.homeDomain.trim()
        : channel.description.trim();
    final joined = joinedChannel != null &&
        isAsChannelMemberJoined(joinedChannel.memberStatus);
    final type = normalizeAsChannelType(
      (joinedChannel?.channelType.trim().isNotEmpty == true
              ? joinedChannel!.channelType
              : channel.channelType)
          .trim(),
    );
    return _ContactChannelItem(
      channelId: channel.channelId.trim().isEmpty
          ? joinedChannel?.channelId.trim() ?? ''
          : channel.channelId.trim(),
      roomId: channel.roomId.trim().isEmpty
          ? joinedChannel?.roomId.trim() ?? ''
          : channel.roomId.trim(),
      title: title,
      subtitle: subtitle,
      avatarUrl: channel.avatarUrl.trim(),
      tag: type == asChannelTypePost
          ? l10n?.contactChannelsPostTag ?? '帖子'
          : l10n?.contactChannelsTextTag ?? '文字',
      channelType: type,
      description: channel.description.trim(),
      joined: joined,
    );
  }

  final String channelId;
  final String roomId;
  final String title;
  final String subtitle;
  final String avatarUrl;
  final String tag;
  final String channelType;
  final String description;
  final bool joined;

  String get routeTarget {
    if (joined && channelId.isNotEmpty) return channelId;
    if (roomId.isNotEmpty) return roomId;
    return channelId;
  }

  String? get openRoute {
    if (!joined) {
      final target = roomId.isNotEmpty ? roomId : channelId;
      return target.isEmpty ? null : detailRoute;
    }
    final target = routeTarget.trim();
    if (target.isEmpty) return null;
    if (normalizeAsChannelType(channelType) == asChannelTypePost) {
      return '/channel/${Uri.encodeComponent(target)}';
    }
    return joinedTextChannelConversationRoute(
          channelId: channelId,
          roomId: roomId,
          memberStatus: asChannelMemberStatusJoined,
          channelType: channelType,
          name: title,
        ) ??
        channelConversationRoute(target, name: title);
  }

  String get detailRoute {
    final params = <String, String>{
      'join': '1',
      if (roomId.isNotEmpty) 'room_id': roomId,
      if (title.trim().isNotEmpty) 'name': title.trim(),
      if (avatarUrl.trim().isNotEmpty) 'avatar': avatarUrl.trim(),
      if (description.trim().isNotEmpty) 'description': description.trim(),
      if (channelType.trim().isNotEmpty) 'type': channelType.trim(),
    };
    final query = params.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');
    final detailTarget = roomId.isNotEmpty ? roomId : channelId;
    final target = Uri.encodeComponent(detailTarget);
    return query.isEmpty
        ? '/channel/$target/detail'
        : '/channel/$target/detail?$query';
  }
}

AsSyncRoomSummary? _viewerJoinedChannel(
  AsSyncBootstrap? bootstrap,
  AsChannel channel,
) {
  if (bootstrap == null) return null;
  final channelId = channel.channelId.trim();
  final roomId = channel.roomId.trim();
  for (final item in bootstrap.channels) {
    final sameChannel =
        channelId.isNotEmpty && item.channelId.trim() == channelId;
    final sameRoom = roomId.isNotEmpty && item.roomId.trim() == roomId;
    if (!sameChannel && !sameRoom) continue;
    if (isAsChannelMemberJoined(item.memberStatus)) return item;
    return null;
  }
  return null;
}

class _ContactChannelListItem extends ConsumerWidget {
  const _ContactChannelListItem({
    required this.item,
    required this.showDivider,
  });

  final _ContactChannelItem item;
  final bool showDivider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final route = item.openRoute;
    final avatarUrl = avatarHttpUrl(
      ref.watch(matrixClientProvider),
      item.avatarUrl,
    );
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: route == null ? null : () => context.push(route),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            PortalAvatar(
              seed: item.title,
              size: 42,
              imageUrl: avatarUrl,
              stableCacheKey: channelAvatarStableCacheKey(
                channelId: item.channelId,
                roomId: item.roomId,
              ),
              shape: AvatarShape.squircle,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 10, right: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.sans(
                                  size: 14,
                                  weight: FontWeight.w600,
                                  color: t.text,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _ChannelTag(text: item.tag),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.sans(size: 12, color: t.textMute),
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      Symbols.chevron_right,
                      size: 24,
                      color: t.text,
                    ),
                  ),
                  if (showDivider)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Divider(
                        height: 1,
                        thickness: 0.5,
                        color: t.surfaceHigh,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelTag extends StatelessWidget {
  const _ChannelTag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      height: 14,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: t.surfaceHigh,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: AppTheme.sans(
          size: 8,
          weight: FontWeight.w500,
          color: t.textMute,
        ),
      ),
    );
  }
}
