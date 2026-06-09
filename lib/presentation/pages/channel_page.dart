import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../channel/channel_inbox_data.dart';
import '../channel/channel_share.dart';
import '../chat/chat_record_forwarding.dart';
import '../mock/mock_channels.dart';
import '../providers/as_bootstrap_store_provider.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/channel_provider.dart';
import '../widgets/m3/glass_header.dart';

class ChannelPage extends ConsumerStatefulWidget {
  const ChannelPage({super.key, required this.channelId});

  final String channelId;

  @override
  ConsumerState<ChannelPage> createState() => _ChannelPageState();
}

class _ChannelPageState extends ConsumerState<ChannelPage> {
  bool _multiSelect = false;
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final realChannel = _findRealChannel(ref, widget.channelId);
    if (realChannel != null) {
      return _RealChannelPage(
        channel: realChannel,
        multiSelect: _multiSelect,
        selected: _selected,
        onTogglePost: _toggleSelected,
        onEnterMultiSelect: _enterMultiSelect,
        onCancelSelection: _cancelSelection,
        onForward: () => _forwardRealChannelSelection(realChannel),
      );
    }

    final channel = MockChannels.byId(widget.channelId);

    if (channel == null) {
      return _PublicChannelScaffold(channelId: widget.channelId);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          GlassHeader.detail(
            title: channel.name,
            subtitle: '${channel.domain} · ${channel.isOwned ? '我的频道' : '已关注'}',
            centerLeading: _ChannelAvatar(channel: channel, size: 34),
            actions: [
              GlassHeaderButton(
                icon: Symbols.more_horiz,
                onTap: () => _showChannelMenu(context, channel),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              children: [
                _MockChannelHero(channel: channel),
                const SizedBox(height: 18),
                const _ChannelPostsHeader(),
                const SizedBox(height: 10),
                for (final post in channel.posts) ...[
                  _ChannelPostCard(
                    channel: channel,
                    post: post,
                    selected: _selected.contains(_mockPostKey(post)),
                    multiSelect: _multiSelect,
                    onTap: _multiSelect
                        ? () => _toggleSelected(_mockPostKey(post))
                        : null,
                    onLongPress: () => _enterMultiSelect(_mockPostKey(post)),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          if (_multiSelect)
            ChatRecordSelectionBar(
              count: _selected.length,
              onExit: _cancelSelection,
              onForward: () => _forwardMockChannelSelection(channel),
            )
          else if (channel.isOwned)
            const _OwnedChannelComposer()
          else
            const _JoinedChannelStatusBar(),
        ],
      ),
    );
  }

  void _enterMultiSelect(String key) {
    setState(() {
      _multiSelect = true;
      _selected.add(key);
    });
  }

  void _toggleSelected(String key) {
    setState(() {
      if (_selected.contains(key)) {
        _selected.remove(key);
      } else {
        _selected.add(key);
      }
    });
  }

  void _cancelSelection() {
    setState(() {
      _multiSelect = false;
      _selected.clear();
    });
  }

  Future<void> _forwardMockChannelSelection(MockChannel channel) async {
    final posts = channel.posts
        .where((post) => _selected.contains(_mockPostKey(post)))
        .toList(growable: false);
    if (posts.isEmpty) return;
    final payload = buildChatRecordPayload(
      sourceRoomId: channel.id,
      sourceRoomType: 'channel',
      sourceName: channel.name,
      messages: [
        for (final post in posts)
          ChatRecordSourceMessage(
            senderName: post.author,
            body: post.body,
            messageType: 'text',
            originServerTs: DateTime.now().millisecondsSinceEpoch,
          ),
      ],
    );
    await _forwardPayload(payload, channel.id, channel.name);
  }

  Future<void> _forwardRealChannelSelection(ChannelInboxItem channel) async {
    if (!_selected.contains('topic')) return;
    final payload = buildChatRecordPayload(
      sourceRoomId: channel.roomId,
      sourceRoomType: 'channel',
      sourceName: channel.name,
      messages: [
        ChatRecordSourceMessage(
          senderName: channel.name,
          body: channel.latestPreview,
          messageType: 'text',
          originServerTs: DateTime.now().millisecondsSinceEpoch,
        ),
      ],
    );
    await _forwardPayload(payload, channel.roomId, channel.name);
  }

  Future<void> _forwardPayload(
    ChatRecordPayload payload,
    String roomId,
    String roomName,
  ) async {
    try {
      final sent = await showAndForwardChatRecord(
        context,
        ref,
        payload: payload,
        currentRoomId: roomId,
        currentRoomName: roomName,
        currentRoomType: 'channel',
      );
      if (!mounted || !sent) return;
      _cancelSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已转发聊天记录')),
      );
    } on Object catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('转发失败：$err')),
      );
    }
  }
}

String _mockPostKey(MockChannelPost post) =>
    '${post.author}|${post.timeLabel}|${post.body}';

ChannelInboxItem? _findRealChannel(WidgetRef ref, String channelId) {
  final bootstrap = ref.watch(asSyncCacheProvider).bootstrap;
  if (bootstrap == null) return null;
  final channels = ChannelInboxData.fromBootstrap(
    bootstrap,
    fallbackDomain: _domainFromRoomId(channelId) ?? 'p2p-im.com',
  );
  for (final channel in channels) {
    if (channel.id == channelId || channel.roomId == channelId) return channel;
  }
  return null;
}

String? _domainFromRoomId(String roomId) {
  final idx = roomId.lastIndexOf(':');
  if (idx < 0 || idx == roomId.length - 1) return null;
  return roomId.substring(idx + 1);
}

class _RealChannelPage extends ConsumerStatefulWidget {
  const _RealChannelPage({
    required this.channel,
    required this.multiSelect,
    required this.selected,
    required this.onTogglePost,
    required this.onEnterMultiSelect,
    required this.onCancelSelection,
    required this.onForward,
  });

  final ChannelInboxItem channel;
  final bool multiSelect;
  final Set<String> selected;
  final ValueChanged<String> onTogglePost;
  final ValueChanged<String> onEnterMultiSelect;
  final VoidCallback onCancelSelection;
  final VoidCallback onForward;

  @override
  ConsumerState<_RealChannelPage> createState() => _RealChannelPageState();
}

class _RealChannelPageState extends ConsumerState<_RealChannelPage> {
  String _lastReadMarkerEventId = '';
  Timeline? _timeline;
  Timer? _timelineSyncDebounce;

  @override
  void initState() {
    super.initState();
    _initChannelTimeline();
  }

  @override
  void didUpdateWidget(covariant _RealChannelPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel.id == widget.channel.id &&
        oldWidget.channel.roomId == widget.channel.roomId) {
      return;
    }
    _lastReadMarkerEventId = '';
    _initChannelTimeline();
  }

  @override
  void dispose() {
    _timeline?.cancelSubscriptions();
    _timelineSyncDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final channel = widget.channel;
    final postsAsync = ref.watch(channelPostsProvider(channel.id));
    final posts = postsAsync.valueOrNull ?? const <AsChannelPost>[];
    _markLatestPostRead(channel, posts);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          GlassHeader.detail(
            title: channel.name,
            subtitle: '${channel.domain} · ${channel.isOwned ? '我的频道' : '已关注'}',
            centerLeading: _RealChannelAvatar(channel: channel, size: 34),
            actions: [
              GlassHeaderButton(
                icon: Symbols.more_horiz,
                onTap: () => _showRealChannelMenu(context, ref, channel),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              children: [
                _RealChannelHero(channel: channel),
                const SizedBox(height: 18),
                const _ChannelPostsHeader(),
                const SizedBox(height: 10),
                if (postsAsync.isLoading && postsAsync.valueOrNull == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (posts.isNotEmpty)
                  for (final post in posts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RealChannelPostCard(
                        channel: channel,
                        post: post,
                        onReaction: () async {
                          await ref
                              .read(asClientProvider)
                              .toggleChannelPostReaction(
                                channel.id,
                                post.postId,
                              );
                          await ref
                              .read(channelPostsProvider(channel.id).notifier)
                              .refresh(silent: true);
                        },
                        onComments: channel.commentsEnabled
                            ? () => _showRealPostComments(
                                  context,
                                  ref,
                                  channel,
                                  post,
                                )
                            : null,
                      ),
                    )
                else if (channel.latestPreview.isNotEmpty &&
                    channel.latestPreview != '暂无频道动态')
                  _ChannelTopicCard(
                    channel: channel,
                    selected: widget.selected.contains('topic'),
                    multiSelect: widget.multiSelect,
                    onTap: widget.multiSelect
                        ? () => widget.onTogglePost('topic')
                        : null,
                    onLongPress: () => widget.onEnterMultiSelect('topic'),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(top: 72),
                    child: _ChannelEmptyState(
                      icon: Symbols.campaign,
                      title: '还没有频道内容',
                      subtitle: '发布后会显示在这里',
                    ),
                  ),
              ],
            ),
          ),
          if (widget.multiSelect)
            ChatRecordSelectionBar(
              count: widget.selected.length,
              onExit: widget.onCancelSelection,
              onForward: widget.onForward,
            )
          else if (channel.isOwned)
            _OwnedChannelComposer(
              channelId: channel.id,
              onPosted: (post) => ref
                  .read(channelPostsProvider(channel.id).notifier)
                  .upsertLocal(post),
            )
          else
            const _JoinedChannelStatusBar(),
        ],
      ),
    );
  }

  void _markLatestPostRead(
    ChannelInboxItem channel,
    List<AsChannelPost> posts,
  ) {
    if (posts.isEmpty) return;
    final latest = posts.first;
    final eventId = latest.eventId.trim();
    if (eventId.isEmpty || eventId == _lastReadMarkerEventId) return;
    _lastReadMarkerEventId = eventId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(asClientProvider).updateChannelReadMarker(
              channel.id,
              eventId: eventId,
              originServerTs: latest.originServerTs,
            );
      } catch (_) {
        // Read marker failure should not block the channel reader UI.
      }
    });
  }

  Future<void> _initChannelTimeline() async {
    _timeline?.cancelSubscriptions();
    _timeline = null;
    final room = ref.read(matrixClientProvider).getRoomById(
          widget.channel.roomId,
        );
    if (room == null) return;

    void scheduleRefresh() {
      if (!mounted) return;
      _timelineSyncDebounce?.cancel();
      _timelineSyncDebounce = Timer(
        const Duration(milliseconds: 450),
        () {
          if (!mounted) return;
          unawaited(
            ref
                .read(channelPostsProvider(widget.channel.id).notifier)
                .refresh(silent: true),
          );
        },
      );
    }

    try {
      _timeline = await room.getTimeline(
        onUpdate: scheduleRefresh,
        onChange: (_) => scheduleRefresh(),
        onInsert: (_) => scheduleRefresh(),
        onRemove: (_) => scheduleRefresh(),
      );
    } on Object catch (e) {
      debugPrint('channel getTimeline failed: $e');
    }
  }
}

class _PublicChannelScaffold extends ConsumerStatefulWidget {
  const _PublicChannelScaffold({required this.channelId});

  final String channelId;

  @override
  ConsumerState<_PublicChannelScaffold> createState() =>
      _PublicChannelScaffoldState();
}

class _PublicChannelScaffoldState
    extends ConsumerState<_PublicChannelScaffold> {
  late Future<AsChannel> _future;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _future = ref.read(asClientProvider).getPublicChannel(widget.channelId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AsChannel>(
      future: _future,
      builder: (context, snapshot) {
        final channel = snapshot.data;
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              GlassHeader.detail(title: channel?.name ?? '频道'),
              Expanded(
                child: _buildBody(snapshot),
              ),
              if (channel != null)
                _PublicChannelJoinBar(
                  channel: channel,
                  joining: _joining,
                  onJoin: () => _join(channel),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(AsyncSnapshot<AsChannel> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    final channel = snapshot.data;
    if (snapshot.hasError || channel == null || channel.channelId.isEmpty) {
      return const _ChannelEmptyState(
        icon: Symbols.search_off,
        title: '频道不存在',
        subtitle: '该频道可能是私密频道、已删除，或目标节点暂时不可达',
      );
    }
    final item = _channelItemFromPublicChannel(channel);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      children: [
        _RealChannelHero(channel: item),
        const SizedBox(height: 18),
        const _ChannelPostsHeader(),
        const SizedBox(height: 10),
        if (item.latestPreview.isNotEmpty && item.latestPreview != '暂无频道动态')
          _ChannelTopicCard(channel: item)
        else
          const Padding(
            padding: EdgeInsets.only(top: 72),
            child: _ChannelEmptyState(
              icon: Symbols.campaign,
              title: '还没有公开内容',
              subtitle: '加入频道后可以查看后续发布内容',
            ),
          ),
      ],
    );
  }

  Future<void> _join(AsChannel channel) async {
    if (_joining) return;
    setState(() => _joining = true);
    try {
      final joined = await ref.read(asClientProvider).joinChannel(
            channel.channelId,
            discoveredChannel: channel,
          );
      setState(() {
        _joining = false;
        _future = Future.value(joined);
      });
      if (joined.memberStatus == asChannelMemberStatusJoined) {
        final bootstrap =
            await ref.read(asBootstrapRepositoryProvider).refresh();
        ref.read(asSyncCacheProvider.notifier).update(
              (state) => state.copyWith(bootstrap: bootstrap),
            );
      }
      if (!mounted) return;
      final message = joined.memberStatus == asChannelMemberStatusPending
          ? '已提交加入申请'
          : '已加入频道';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (err) {
      if (!mounted) return;
      setState(() => _joining = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加入频道失败：$err')),
      );
    }
  }
}

ChannelInboxItem _channelItemFromPublicChannel(AsChannel channel) {
  final roomId = channel.roomId.trim();
  final channelId = channel.channelId.trim();
  final fallbackId = channelId.isEmpty ? roomId : channelId;
  return ChannelInboxItem(
    id: fallbackId,
    roomId: roomId,
    name: channel.name.trim().isEmpty ? '未命名频道' : channel.name.trim(),
    domain: channel.homeDomain.trim().isEmpty
        ? _domainFromRoomId(roomId) ?? ''
        : channel.homeDomain.trim(),
    avatarUrl: channel.avatarUrl,
    latestPreview: channel.description.trim().isEmpty
        ? '暂无频道动态'
        : channel.description.trim(),
    latestAt: channel.latestActivityAt,
    unreadCount: 0,
    isOwned: channel.role == asChannelRoleOwner ||
        channel.role == asChannelRoleAdmin,
    tags: channel.tags,
    description: channel.description,
    visibility: channel.visibility,
    joinPolicy: channel.joinPolicy,
    commentsEnabled: channel.commentsEnabled,
    role: channel.role,
    memberStatus: channel.memberStatus,
    memberCount: channel.memberCount,
    pendingJoinCount: channel.pendingJoinCount,
  );
}

class _PublicChannelJoinBar extends StatelessWidget {
  const _PublicChannelJoinBar({
    required this.channel,
    required this.joining,
    required this.onJoin,
  });

  final AsChannel channel;
  final bool joining;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final status = channel.memberStatus.trim();
    final joined = status == asChannelMemberStatusJoined;
    final pending = status == asChannelMemberStatusPending;
    final approval = channel.joinPolicy == asChannelJoinPolicyApproval;
    final label = joined
        ? '已加入'
        : pending
            ? '待审核'
            : approval
                ? '申请加入'
                : '加入频道';
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: t.surface,
          border:
              Border(top: BorderSide(color: t.border.withValues(alpha: 0.5))),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 44,
          child: FilledButton(
            onPressed: joined || pending || joining ? null : onJoin,
            child: Text(joining ? '处理中' : label),
          ),
        ),
      ),
    );
  }
}

class _MockChannelHero extends StatelessWidget {
  const _MockChannelHero({required this.channel});

  final MockChannel channel;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          _ChannelAvatar(channel: channel, size: 58),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.sans(
                          size: 20,
                          weight: FontWeight.w600,
                          color: t.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const _ChannelSampleBadge(),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  channel.handle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(size: 13, color: t.textMute),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ChannelMetaPill(
                      icon: Symbols.notifications,
                      text: channel.isOwned ? '我的频道' : '已关注',
                    ),
                    _ChannelMetaPill(
                      icon: Symbols.local_offer,
                      text: channel.tags.take(2).join(' / '),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RealChannelHero extends StatelessWidget {
  const _RealChannelHero({required this.channel});

  final ChannelInboxItem channel;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          _RealChannelAvatar(channel: channel, size: 58),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(
                    size: 20,
                    weight: FontWeight.w600,
                    color: t.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  channel.domain,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(size: 13, color: t.textMute),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ChannelMetaPill(
                      icon: Symbols.notifications,
                      text: channel.isOwned ? '我的频道' : '已关注',
                    ),
                    for (final tag in channel.tags.take(2))
                      _ChannelMetaPill(icon: Symbols.local_offer, text: tag),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelSampleBadge extends StatelessWidget {
  const _ChannelSampleBadge();

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: t.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '设计样例',
        style: AppTheme.sans(
          size: 11,
          weight: FontWeight.w600,
          color: t.textMute,
        ),
      ),
    );
  }
}

class _ChannelMetaPill extends StatelessWidget {
  const _ChannelMetaPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: t.surfaceHover,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: t.textMute),
          const SizedBox(width: 4),
          Text(text, style: AppTheme.sans(size: 12, color: t.textMute)),
        ],
      ),
    );
  }
}

class _ChannelPostsHeader extends StatelessWidget {
  const _ChannelPostsHeader();

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Text(
      '频道帖子',
      style: AppTheme.sans(
        size: 15,
        weight: FontWeight.w600,
        color: t.text,
      ),
    );
  }
}

void _showRealChannelMenu(
  BuildContext context,
  WidgetRef ref,
  ChannelInboxItem channel,
) {
  final items = channel.isOwned
      ? const ['分享频道', '管理频道', '成员管理', '通知设置']
      : const ['分享频道', '频道资料', '通知设置', '退出频道'];
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in items)
            ListTile(
              title: Text(item),
              onTap: () {
                Navigator.of(ctx).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!context.mounted) return;
                  if (item == '分享频道') {
                    _shareRealChannel(context, ref, channel);
                  } else if (item == '管理频道') {
                    context.push(
                      '/channels/manage/${Uri.encodeComponent(channel.id)}',
                    );
                  } else if (item == '成员管理') {
                    context.push(
                      '/channels/manage/${Uri.encodeComponent(channel.id)}?tab=members',
                    );
                  } else if (item == '频道资料') {
                    context.push(
                      '/channels/manage/${Uri.encodeComponent(channel.id)}?tab=profile',
                    );
                  }
                });
              },
            ),
        ],
      ),
    ),
  );
}

Future<void> _shareRealChannel(
  BuildContext context,
  WidgetRef ref,
  ChannelInboxItem channel,
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
        tags: channel.tags,
      ),
      currentRoomId: channel.roomId,
      currentRoomName: channel.name,
    );
    if (!context.mounted || !sent) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已分享频道')),
    );
  } on Object catch (err) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('分享频道失败：$err')),
    );
  }
}

// ignore: unused_element
void _showChannelMembersSheet(
  BuildContext context,
  WidgetRef ref,
  ChannelInboxItem channel,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _ChannelMembersSheet(channel: channel),
  );
}

// ignore: unused_element
void _showManageChannelSheet(
  BuildContext context,
  ChannelInboxItem channel,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _ManageChannelSheet(channel: channel),
  );
}

class _ChannelMembersSheet extends ConsumerWidget {
  const _ChannelMembersSheet({required this.channel});

  final ChannelInboxItem channel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final key = ChannelMembersKey(
      channelId: channel.id,
      status: asChannelMemberStatusPending,
    );
    final pending = ref.watch(channelMembersProvider(key));
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '成员管理',
              style: AppTheme.sans(
                size: 20,
                weight: FontWeight.w600,
                color: t.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '待审核加入申请',
              style: AppTheme.sans(size: 13, color: t.textMute),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: pending.when(
                data: (members) {
                  if (members.isEmpty) {
                    return const _ChannelEmptyState(
                      icon: Symbols.group,
                      title: '暂无待审核成员',
                      subtitle: '需要审核的加入申请会显示在这里',
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: members.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, index) {
                      final member = members[index];
                      return _PendingChannelMemberRow(
                        member: member,
                        onApprove: () => _resolvePendingMember(
                          context,
                          ref,
                          channel,
                          member,
                          approve: true,
                        ),
                        onReject: () => _resolvePendingMember(
                          context,
                          ref,
                          channel,
                          member,
                          approve: false,
                        ),
                      );
                    },
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const _ChannelEmptyState(
                  icon: Symbols.error,
                  title: '成员加载失败',
                  subtitle: '请稍后重试',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resolvePendingMember(
    BuildContext context,
    WidgetRef ref,
    ChannelInboxItem channel,
    AsChannelMember member, {
    required bool approve,
  }) async {
    try {
      final updated = approve
          ? await ref
              .read(asClientProvider)
              .approveChannelJoin(channel.id, member.userMxid)
          : await ref
              .read(asClientProvider)
              .rejectChannelJoin(channel.id, member.userMxid);
      _mergeUpdatedChannelIntoCache(ref, channel, updated);
      ref.invalidate(
        channelMembersProvider(
          ChannelMembersKey(
            channelId: channel.id,
            status: asChannelMemberStatusPending,
          ),
        ),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? '已同意加入申请' : '已拒绝加入申请')),
      );
    } catch (err) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? '同意失败：$err' : '拒绝失败：$err')),
      );
    }
  }
}

class _PendingChannelMemberRow extends StatelessWidget {
  const _PendingChannelMemberRow({
    required this.member,
    required this.onApprove,
    required this.onReject,
  });

  final AsChannelMember member;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final name = member.displayName.trim().isEmpty
        ? _localpartFromMxid(member.userMxid)
        : member.displayName.trim();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: t.secondaryContainer,
            child: Text(
              name.isEmpty ? '' : name.characters.first,
              style: AppTheme.sans(
                size: 15,
                weight: FontWeight.w700,
                color: t.text,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(
                    size: 15,
                    weight: FontWeight.w600,
                    color: t.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  member.userMxid,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(size: 12, color: t.textMute),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            height: 36,
            child: TextButton(
              onPressed: onReject,
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: const Text('拒绝'),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 56,
            height: 36,
            child: FilledButton(
              onPressed: onApprove,
              style: FilledButton.styleFrom(padding: EdgeInsets.zero),
              child: const Text('同意'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManageChannelSheet extends ConsumerStatefulWidget {
  const _ManageChannelSheet({required this.channel});

  final ChannelInboxItem channel;

  @override
  ConsumerState<_ManageChannelSheet> createState() =>
      _ManageChannelSheetState();
}

class _ManageChannelSheetState extends ConsumerState<_ManageChannelSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _tagsCtrl;
  late String _visibility;
  late String _joinPolicy;
  late bool _commentsEnabled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final channel = widget.channel;
    _nameCtrl = TextEditingController(text: channel.name);
    _descriptionCtrl = TextEditingController(text: channel.description);
    _tagsCtrl = TextEditingController(text: channel.tags.join(', '));
    _visibility = _normalizedChannelVisibility(channel.visibility);
    _joinPolicy = _normalizedChannelJoinPolicy(channel.joinPolicy);
    _commentsEnabled = channel.commentsEnabled;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final channel = widget.channel;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _saving) {
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('频道名称不能为空')),
        );
      }
      return;
    }
    setState(() => _saving = true);
    try {
      final updated = await ref.read(asClientProvider).updateChannel(
            AsChannel(
              channelId: channel.id,
              roomId: channel.roomId,
              homeDomain: channel.domain,
              name: name,
              description: _descriptionCtrl.text.trim(),
              avatarUrl: channel.avatarUrl,
              visibility: _visibility,
              joinPolicy: _joinPolicy,
              commentsEnabled: _commentsEnabled,
              role: channel.role,
              memberStatus: channel.memberStatus,
              memberCount: channel.memberCount,
              pendingJoinCount: channel.pendingJoinCount,
              tags: _parseChannelTags(_tagsCtrl.text),
              latestActivityAt: channel.latestAt,
            ),
          );
      _mergeUpdatedChannelIntoCache(ref, channel, updated);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('频道已更新')),
      );
    } catch (err) {
      if (mounted) setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('频道更新失败：$err')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '管理频道',
                style: AppTheme.sans(
                  size: 20,
                  weight: FontWeight.w600,
                  color: t.text,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '频道名称',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '频道简介',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tagsCtrl,
                decoration: const InputDecoration(
                  labelText: '频道标签',
                  helperText: '用逗号分隔多个标签',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _visibility,
                decoration: const InputDecoration(
                  labelText: '可见范围',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: asChannelVisibilityPublic,
                    child: Text('公开'),
                  ),
                  DropdownMenuItem(
                    value: asChannelVisibilityPrivate,
                    child: Text('私密'),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() {
                          _visibility = _normalizedChannelVisibility(
                            value ?? _visibility,
                          );
                        }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _joinPolicy,
                decoration: const InputDecoration(
                  labelText: '加入方式',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: asChannelJoinPolicyOpen,
                    child: Text('直接加入'),
                  ),
                  DropdownMenuItem(
                    value: asChannelJoinPolicyApproval,
                    child: Text('需要审核'),
                  ),
                  DropdownMenuItem(
                    value: asChannelJoinPolicyInvite,
                    child: Text('仅邀请'),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() {
                          _joinPolicy = _normalizedChannelJoinPolicy(
                            value ?? _joinPolicy,
                          );
                        }),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('允许评论'),
                value: _commentsEnabled,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _commentsEnabled = value),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? '保存中' : '保存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<String> _parseChannelTags(String value) {
  return value
      .split(RegExp(r'[,，]'))
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

String _normalizedChannelVisibility(String value) {
  return value == asChannelVisibilityPrivate
      ? asChannelVisibilityPrivate
      : asChannelVisibilityPublic;
}

String _normalizedChannelJoinPolicy(String value) {
  return switch (value) {
    asChannelJoinPolicyApproval => asChannelJoinPolicyApproval,
    asChannelJoinPolicyInvite => asChannelJoinPolicyInvite,
    _ => asChannelJoinPolicyOpen,
  };
}

void _mergeUpdatedChannelIntoCache(
  WidgetRef ref,
  ChannelInboxItem previous,
  AsChannel updated,
) {
  final current = ref.read(asSyncCacheProvider).bootstrap;
  if (current == null) return;
  var replaced = false;
  final channels = current.channels.map((summary) {
    final sameChannelId = summary.channelId.trim().isNotEmpty &&
        summary.channelId.trim() == previous.id.trim();
    final sameRoomId = summary.roomId.trim().isNotEmpty &&
        summary.roomId.trim() == previous.roomId.trim();
    if (!sameChannelId && !sameRoomId) return summary;
    replaced = true;
    return _summaryFromUpdatedChannel(summary, updated, previous);
  }).toList(growable: true);
  if (!replaced) {
    channels.add(_summaryFromUpdatedChannel(null, updated, previous));
  }
  ref.read(asSyncCacheProvider.notifier).update(
        (state) => state.copyWith(
          bootstrap: AsSyncBootstrap(
            syncedAt: DateTime.now().toUtc(),
            user: current.user,
            agentRoomId: current.agentRoomId,
            rooms: current.rooms,
            contacts: current.contacts,
            groups: current.groups,
            channels: channels,
            pending: current.pending,
          ),
        ),
      );
}

AsSyncRoomSummary _summaryFromUpdatedChannel(
  AsSyncRoomSummary? previous,
  AsChannel updated,
  ChannelInboxItem fallback,
) {
  return AsSyncRoomSummary(
    channelId: updated.channelId.trim().isEmpty
        ? fallback.id
        : updated.channelId.trim(),
    roomId:
        updated.roomId.trim().isEmpty ? fallback.roomId : updated.roomId.trim(),
    homeDomain: updated.homeDomain.trim().isEmpty
        ? fallback.domain
        : updated.homeDomain.trim(),
    name: updated.name.trim().isEmpty ? fallback.name : updated.name.trim(),
    avatarUrl: updated.avatarUrl,
    unreadCount: previous?.unreadCount ?? fallback.unreadCount,
    lastActivityAt: updated.latestActivityAt ?? fallback.latestAt,
    description: updated.description,
    topic: previous?.topic ?? '',
    isOwned: fallback.isOwned,
    tags: updated.tags,
    invitePolicy: previous?.invitePolicy ?? groupInvitePolicyAllMembers,
    visibility: updated.visibility,
    joinPolicy: updated.joinPolicy,
    commentsEnabled: updated.commentsEnabled,
    role: updated.role.trim().isEmpty ? fallback.role : updated.role,
    memberStatus: updated.memberStatus.trim().isEmpty
        ? fallback.memberStatus
        : updated.memberStatus,
    memberCount: updated.memberCount,
    pendingJoinCount: updated.pendingJoinCount,
  );
}

class _RealChannelAvatar extends StatelessWidget {
  const _RealChannelAvatar({required this.channel, required this.size});

  final ChannelInboxItem channel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: t.accent.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        Symbols.campaign,
        size: size * 0.52,
        color: t.accent,
        fill: 1,
      ),
    );
  }
}

class _RealChannelPostCard extends StatelessWidget {
  const _RealChannelPostCard({
    required this.channel,
    required this.post,
    this.onReaction,
    this.onComments,
  });

  final ChannelInboxItem channel;
  final AsChannelPost post;
  final Future<void> Function()? onReaction;
  final VoidCallback? onComments;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RealChannelAvatar(channel: channel, size: 30),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  post.authorName.trim().isEmpty
                      ? _localpartFromMxid(post.authorId)
                      : post.authorName.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(
                    size: 13,
                    weight: FontWeight.w600,
                    color: t.text,
                  ),
                ),
              ),
              Text(
                _formatPostTime(post.originServerTs),
                style: AppTheme.sans(size: 12, color: t.textMute),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            post.body.trim().isEmpty ? '[${post.messageType}]' : post.body,
            style:
                AppTheme.sans(size: 15, color: t.text).copyWith(height: 1.45),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Symbols.visibility, size: 15, color: t.textMute),
              const SizedBox(width: 4),
              Text('频道', style: AppTheme.sans(size: 12, color: t.textMute)),
              const Spacer(),
              TextButton.icon(
                onPressed: onReaction == null ? null : () => onReaction!(),
                icon: Icon(
                  post.reactedByMe ? Icons.favorite : Icons.favorite_border,
                  size: 16,
                ),
                label: Text('点赞 ${post.reactionCount}'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: onComments,
                icon: const Icon(Symbols.forum, size: 16),
                label: Text('评论 ${post.commentCount}'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void _showRealPostComments(
  BuildContext context,
  WidgetRef ref,
  ChannelInboxItem channel,
  AsChannelPost post,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _RealPostCommentsSheet(channel: channel, post: post),
  );
}

class _RealPostCommentsSheet extends ConsumerStatefulWidget {
  const _RealPostCommentsSheet({
    required this.channel,
    required this.post,
  });

  final ChannelInboxItem channel;
  final AsChannelPost post;

  @override
  ConsumerState<_RealPostCommentsSheet> createState() =>
      _RealPostCommentsSheetState();
}

class _RealPostCommentsSheetState
    extends ConsumerState<_RealPostCommentsSheet> {
  final _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final channel = widget.channel;
    final post = widget.post;
    final key = ChannelCommentsKey(channelId: channel.id, postId: post.postId);
    final comments = ref.watch(channelCommentsProvider(key));
    final t = context.tk;

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          12 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '评论线程',
                      style: AppTheme.sans(
                        size: 20,
                        weight: FontWeight.w600,
                        color: t.text,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('channel_comments_close'),
                    tooltip: '关闭评论',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Symbols.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.surfaceHover,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  post.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(size: 14, color: t.text)
                      .copyWith(height: 1.4),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SizedBox(
                  height: 180,
                  child: comments.when(
                    data: (items) => items.isEmpty
                        ? Center(
                            child: Text(
                              '还没有评论',
                              style: AppTheme.sans(size: 13, color: t.textMute),
                            ),
                          )
                        : ListView(
                            children: [
                              for (final item in items)
                                _CommentPreviewRow(
                                  name: item.authorName.trim().isEmpty
                                      ? _localpartFromMxid(item.authorId)
                                      : item.authorName.trim(),
                                  text: item.body,
                                ),
                            ],
                          ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) => Center(
                      child: Text(
                        '评论加载失败',
                        style: AppTheme.sans(size: 13, color: t.textMute),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(hintText: '写评论'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(72, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () async {
                      final body = _commentCtrl.text.trim();
                      if (body.isEmpty) return;
                      await ref.read(asClientProvider).createChannelComment(
                            channel.id,
                            post.postId,
                            messageType: 'text',
                            body: body,
                          );
                      _commentCtrl.clear();
                      ref.invalidate(channelCommentsProvider(key));
                      unawaited(
                        ref
                            .read(channelPostsProvider(channel.id).notifier)
                            .refresh(silent: true),
                      );
                    },
                    child: const Text('发送'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _localpartFromMxid(String mxid) {
  if (!mxid.startsWith('@')) return mxid.trim().isEmpty ? '用户' : mxid.trim();
  final colon = mxid.indexOf(':');
  final end = colon < 0 ? mxid.length : colon;
  return mxid.substring(1, end).trim().isEmpty
      ? '用户'
      : mxid.substring(1, end).trim();
}

String _formatPostTime(int originServerTs) {
  if (originServerTs <= 0) return '';
  final dt = DateTime.fromMillisecondsSinceEpoch(originServerTs);
  final now = DateTime.now();
  final sameDay =
      dt.year == now.year && dt.month == now.month && dt.day == now.day;
  if (sameDay) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
  return '${dt.month}.${dt.day}';
}

class _ChannelTopicCard extends StatelessWidget {
  const _ChannelTopicCard({
    required this.channel,
    this.selected = false,
    this.multiSelect = false,
    this.onTap,
    this.onLongPress,
  });

  final ChannelInboxItem channel;
  final bool selected;
  final bool multiSelect;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? t.accent.withValues(alpha: 0.12) : t.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? t.accent : t.border.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (multiSelect) ...[
              _ChannelSelectCheckmark(
                selected: selected,
                onTap: onTap,
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                channel.latestPreview,
                style: AppTheme.sans(size: 15, color: t.text)
                    .copyWith(height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showChannelMenu(BuildContext context, MockChannel channel) {
  final items = channel.isOwned
      ? const ['频道资料', '成员管理', '标签管理', '通知设置']
      : const ['频道资料', '通知设置', '退出频道'];
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in items)
            ListTile(
              title: Text(item),
              onTap: () {
                Navigator.of(ctx).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!context.mounted) return;
                  if (item == '频道资料') {
                    context.push(
                      '/channels/manage/${Uri.encodeComponent(channel.id)}?tab=profile',
                    );
                  } else if (item == '成员管理') {
                    context.push(
                      '/channels/manage/${Uri.encodeComponent(channel.id)}?tab=members',
                    );
                  } else if (item == '标签管理') {
                    context.push(
                      '/channels/manage/${Uri.encodeComponent(channel.id)}?tab=moderation',
                    );
                  }
                });
              },
            ),
        ],
      ),
    ),
  );
}

class _ChannelAvatar extends StatelessWidget {
  const _ChannelAvatar({required this.channel, required this.size});

  final MockChannel channel;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: channel.color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        channel.icon,
        size: size * 0.52,
        color: channel.color,
        fill: 1,
      ),
    );
  }
}

class _ChannelPostCard extends StatelessWidget {
  const _ChannelPostCard({
    required this.channel,
    required this.post,
    this.selected = false,
    this.multiSelect = false,
    this.onTap,
    this.onLongPress,
  });

  final MockChannel channel;
  final MockChannelPost post;
  final bool selected;
  final bool multiSelect;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? t.accent.withValues(alpha: 0.12) : t.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? t.accent : t.border.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (multiSelect) ...[
                  _ChannelSelectCheckmark(
                    selected: selected,
                    onTap: onTap,
                  ),
                  const SizedBox(width: 8),
                ],
                _ChannelAvatar(channel: channel, size: 30),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    post.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(
                      size: 13,
                      weight: FontWeight.w600,
                      color: t.text,
                    ),
                  ),
                ),
                Text(
                  post.timeLabel,
                  style: AppTheme.sans(size: 12, color: t.textMute),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              post.body,
              style: AppTheme.sans(size: 15, color: t.text).copyWith(
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Symbols.visibility, size: 15, color: t.textMute),
                const SizedBox(width: 4),
                Text(
                  post.views,
                  style: AppTheme.sans(size: 12, color: t.textMute),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: t.surfaceHover,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    post.reactionLabel,
                    style: AppTheme.sans(size: 12, color: t.text),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _showPostComments(context, channel, post),
                  icon: const Icon(Symbols.forum, size: 16),
                  label: Text('评论 ${post.commentCount}'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Symbols.reply, size: 16, color: t.textMute),
                const SizedBox(width: 10),
                Icon(Symbols.ios_share, size: 16, color: t.textMute),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void _showPostComments(
  BuildContext context,
  MockChannel channel,
  MockChannelPost post,
) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final t = ctx.tk;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '评论线程',
                style: AppTheme.sans(
                  size: 20,
                  weight: FontWeight.w600,
                  color: t.text,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.surfaceHover,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  post.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(size: 14, color: t.text).copyWith(
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _CommentPreviewRow(
                name: channel.isOwned ? 'Alice' : 'Li',
                text: '这个方向可以先做成频道详情样例，再接真实帖子接口。',
              ),
              _CommentPreviewRow(
                name: channel.isOwned ? 'Mira' : 'Chen',
                text: '评论应该跟着单条帖子走，不要混到频道主流里。',
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _CommentPreviewRow extends StatelessWidget {
  const _CommentPreviewRow({required this.name, required this.text});

  final String name;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: t.secondaryContainer,
            child: Text(
              name.isEmpty ? '' : name.substring(0, 1),
              style: AppTheme.sans(
                size: 12,
                weight: FontWeight.w600,
                color: t.textMute,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTheme.sans(
                    size: 13,
                    weight: FontWeight.w600,
                    color: t.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: AppTheme.sans(size: 13, color: t.textMute).copyWith(
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnedChannelComposer extends ConsumerStatefulWidget {
  const _OwnedChannelComposer({
    this.channelId = '',
    this.onPosted,
  });

  final String channelId;
  final FutureOr<void> Function(AsChannelPost post)? onPosted;

  @override
  ConsumerState<_OwnedChannelComposer> createState() =>
      _OwnedChannelComposerState();
}

class _OwnedChannelComposerState extends ConsumerState<_OwnedChannelComposer> {
  final _ctrl = TextEditingController();
  bool _posting = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final channelId = widget.channelId.trim();
    final body = _ctrl.text.trim();
    if (channelId.isEmpty || body.isEmpty || _posting) return;
    setState(() => _posting = true);
    try {
      final post = await ref.read(asClientProvider).createChannelPost(
            channelId,
            messageType: 'text',
            body: body,
          );
      _ctrl.clear();
      await widget.onPosted?.call(post);
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发布失败：$err')),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: t.surface,
          border:
              Border(top: BorderSide(color: t.border.withValues(alpha: 0.5))),
        ),
        child: Row(
          children: [
            GlassHeaderButton(
              icon: Symbols.add_photo_alternate,
              size: 36,
              iconSize: 20,
              onTap: () {},
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: t.surfaceHover,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _ctrl,
                  minLines: 1,
                  maxLines: 3,
                  style: AppTheme.sans(size: 14, color: t.text),
                  decoration: InputDecoration(
                    hintText: '写一条频道帖子',
                    hintStyle: AppTheme.sans(size: 14, color: t.textMute),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 104,
              height: 40,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                ),
                onPressed: _posting ? null : _post,
                child: Text(_posting ? '发布中' : '发布帖子'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinedChannelStatusBar extends StatelessWidget {
  const _JoinedChannelStatusBar();

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: t.surface,
          border:
              Border(top: BorderSide(color: t.border.withValues(alpha: 0.5))),
        ),
        child: Row(
          children: [
            Icon(Symbols.check_circle, size: 20, color: t.textMute),
            const SizedBox(width: 8),
            Text(
              '已关注',
              style: AppTheme.sans(
                size: 15,
                weight: FontWeight.w600,
                color: t.text,
              ),
            ),
            const Spacer(),
            Text('接收通知', style: AppTheme.sans(size: 13, color: t.textMute)),
          ],
        ),
      ),
    );
  }
}

class _ChannelSelectCheckmark extends StatelessWidget {
  const _ChannelSelectCheckmark({
    required this.selected,
    required this.onTap,
  });

  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Semantics(
      button: true,
      label: selected ? '取消选择消息' : '选择消息',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: 40,
          child: Center(
            child: Icon(
              selected ? Symbols.check_circle : Symbols.circle,
              size: 22,
              color: selected ? t.accent : t.textMute,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelEmptyState extends StatelessWidget {
  const _ChannelEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: t.textMute),
          const SizedBox(height: 12),
          Text(
            title,
            style: AppTheme.sans(
              size: 15,
              weight: FontWeight.w600,
              color: t.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: AppTheme.sans(size: 12, color: t.textMute)),
        ],
      ),
    );
  }
}
