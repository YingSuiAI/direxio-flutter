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
import '../chat/chat_record_forwarding.dart';
import '../mock/mock_channels.dart';
import '../providers/as_bootstrap_store_provider.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/channel_provider.dart';
import '../utils/contact_identity_label.dart';
import '../widgets/m3/glass_header.dart';
import 'channel_info_page.dart';

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
      backgroundColor: _channelPageBackground(context),
      floatingActionButton: !_multiSelect && channel.isOwned
          ? _ChannelPostCreateFab(
              key: const ValueKey('channel_post_create_fab'),
              onTap: () => context.push(
                '/channel/${Uri.encodeComponent(channel.id)}/post/create',
              ),
            )
          : null,
      body: Column(
        children: [
          GlassHeader.detail(
            title: _mockPostChannelTitle(channel.name),
            actions: [
              GlassHeaderButton(
                icon: Symbols.more_vert,
                onTap: () => _showChannelMenu(context, channel),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 18),
              children: [
                if (channel.posts.isNotEmpty) ...[
                  const _ChannelIntroPill(),
                  const SizedBox(height: 20),
                ],
                for (final post in channel.posts) ...[
                  _ChannelPostCard(
                    channel: channel,
                    post: post,
                    selected: _selected.contains(_mockPostKey(post)),
                    multiSelect: _multiSelect,
                    onTap: _multiSelect
                        ? () => _toggleSelected(_mockPostKey(post))
                        : () => context.push(
                              '/channel/${Uri.encodeComponent(channel.id)}'
                              '/post/${Uri.encodeComponent(_mockPostKey(post))}',
                            ),
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
            ),
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

String _realPostKey(AsChannelPost post) {
  final postId = post.postId.trim();
  if (postId.isNotEmpty) return postId;
  final eventId = post.eventId.trim();
  if (eventId.isNotEmpty) return eventId;
  return '${post.authorId}|${post.originServerTs}|${post.body}';
}

ChannelInboxItem? _findRealChannel(WidgetRef ref, String channelId) {
  final bootstrap = ref.watch(asSyncCacheProvider).bootstrap;
  if (bootstrap == null) return null;
  final client = ref.watch(matrixClientProvider);
  final channels = ChannelInboxData.fromBootstrap(
    bootstrap,
    fallbackDomain: _domainFromRoomId(channelId) ?? 'p2p-im.com',
    roomNameForRoomId: (roomId) => _matrixRoomName(client, roomId),
    roomAvatarForRoomId: (roomId) => _matrixRoomAvatar(client, roomId),
  );
  for (final channel in channels) {
    if (channel.id == channelId || channel.roomId == channelId) return channel;
  }
  return null;
}

String? _domainFromRoomId(String roomId) {
  final domain = serverNameFromMatrixId(roomId);
  return domain.isEmpty ? null : domain;
}

String _matrixRoomName(Client client, String roomId) {
  final room = client.getRoomById(roomId.trim());
  if (room == null) return '';
  final name = room.getLocalizedDisplayname().trim();
  return _looksLikeMatrixRoomId(name) ? '' : name;
}

String _matrixRoomAvatar(Client client, String roomId) {
  return client.getRoomById(roomId.trim())?.avatar?.toString() ?? '';
}

class _ChannelModalSurface extends StatelessWidget {
  const _ChannelModalSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      key: const ValueKey('channel_modal_surface'),
      color: t.surface,
      child: IconTheme(
        data: IconThemeData(color: t.textMute),
        child: DefaultTextStyle(
          style: AppTheme.sans(size: 15, color: t.text),
          child: child,
        ),
      ),
    );
  }
}

Color _channelPageBackground(BuildContext context) {
  return context.tk.bg;
}

Color _channelModalBackground(BuildContext context) {
  return context.tk.surface;
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
      backgroundColor: _channelPageBackground(context),
      floatingActionButton: !widget.multiSelect && channel.isOwned
          ? _ChannelPostCreateFab(
              key: const ValueKey('channel_post_create_fab'),
              onTap: () => context.push(
                '/channel/${Uri.encodeComponent(channel.id)}/post/create',
              ),
            )
          : null,
      body: Column(
        children: [
          GlassHeader.detail(
            title: _postChannelTitle(channel.name),
            titleTrailing: _channelTitleLock(context, channel.visibility),
            actions: [
              GlassHeaderButton(
                icon: Symbols.more_vert,
                onTap: () => _openRealChannelInfo(context, channel),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 18),
              children: [
                if (posts.isNotEmpty) ...[
                  const _ChannelIntroPill(),
                  const SizedBox(height: 20),
                ],
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
                        onOpen: () => context.push(
                          '/channel/${Uri.encodeComponent(channel.id)}'
                          '/post/${Uri.encodeComponent(_realPostKey(post))}',
                        ),
                        onReaction: () async {
                          await ref
                              .read(asClientProvider)
                              .toggleChannelPostReaction(
                                channel.id,
                                _realPostKey(post),
                              );
                          await ref
                              .read(channelPostsProvider(channel.id).notifier)
                              .refresh(silent: true);
                        },
                        onRecall: _canRecallPost(channel, post)
                            ? () => _recallPost(channel, post)
                            : null,
                      ),
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
            ),
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

  bool _canRecallPost(ChannelInboxItem channel, AsChannelPost post) {
    return channel.isOwned && post.postId.trim().isNotEmpty;
  }

  Future<void> _recallPost(ChannelInboxItem channel, AsChannelPost post) async {
    final postId = post.postId.trim();
    if (postId.isEmpty) return;
    try {
      await ref.read(asClientProvider).recallChannelPost(
            channel.id,
            postId,
            reason: 'recall post',
          );
      await ref.read(channelPostsProvider(channel.id).notifier).removeLocal(
            postId,
          );
      unawaited(
        ref.read(channelPostsProvider(channel.id).notifier).refresh(
              silent: true,
            ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('帖子已删除')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除帖子失败：$error')),
      );
    }
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
    _future = _loadPublicChannel(widget.channelId);
  }

  @override
  void didUpdateWidget(covariant _PublicChannelScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channelId == widget.channelId) return;
    _future = _loadPublicChannel(widget.channelId);
  }

  Future<AsChannel> _loadPublicChannel(String id) {
    final trimmed = id.trim();
    final client = ref.read(asClientProvider);
    if (_looksLikeMatrixRoomId(trimmed)) {
      return client.getPublicChannelByRoomId(trimmed);
    }
    return client.getPublicChannel(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AsChannel>(
      future: _future,
      builder: (context, snapshot) {
        final channel = snapshot.data;
        return Scaffold(
          backgroundColor: _channelPageBackground(context),
          body: Column(
            children: [
              GlassHeader.detail(
                title: channel == null ? '频道' : _postChannelTitle(channel.name),
                subtitle: channel?.homeDomain,
                titleTrailing:
                    _channelTitleLock(context, channel?.visibility ?? ''),
              ),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      children: const [
        Padding(
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
    final roomId = channel.roomId.trim();
    if (roomId.isEmpty) return;
    setState(() => _joining = true);
    try {
      final joined = await ref.read(asClientProvider).joinChannelByRoomId(
            roomId,
            discoveredChannel: channel,
          );
      setState(() {
        _joining = false;
        _future = Future.value(joined);
      });
      if (!mounted) return;
      if (isAsChannelMemberAwaitingJoin(joined.memberStatus)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_channelJoinWaitingText(joined.memberStatus))),
        );
        return;
      }
      if (!isAsChannelMemberJoined(joined.memberStatus)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('频道加入状态未完成，请稍后刷新')),
        );
        return;
      }
      final bootstrap = await ref.read(asBootstrapRepositoryProvider).refresh();
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.copyWith(bootstrap: bootstrap),
          );
      if (!mounted) return;
      _openJoinedPublicChannel(context, joined, fallback: channel);
    } catch (err) {
      if (!mounted) return;
      setState(() => _joining = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加入频道失败：$err')),
      );
    }
  }
}

String _channelJoinWaitingText(String memberStatus) {
  return memberStatus == asChannelMemberStatusPending
      ? '已提交加入申请'
      : '已发送频道邀请，等待加入完成';
}

bool _looksLikeMatrixRoomId(String value) {
  return value.startsWith('!') && value.contains(':');
}

Widget? _channelTitleLock(BuildContext context, String visibility) {
  if (visibility != asChannelVisibilityPrivate) return null;
  return Icon(
    Symbols.lock,
    size: 15,
    color: context.tk.accent,
    fill: 1,
  );
}

String _postChannelTitle(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '频道';
  return trimmed.startsWith('#') ? trimmed.substring(1).trim() : trimmed;
}

String _mockPostChannelTitle(String name) {
  final title = _postChannelTitle(name);
  return title.startsWith('#') ? title : '#$title';
}

void _openJoinedPublicChannel(
  BuildContext context,
  AsChannel joined, {
  required AsChannel fallback,
}) {
  final channelId = joined.channelId.trim().isEmpty
      ? fallback.channelId.trim()
      : joined.channelId.trim();
  if (channelId.isEmpty) return;
  final encodedChannelId = Uri.encodeComponent(channelId);
  if (normalizeAsChannelType(joined.channelType) == asChannelTypePost) {
    context.go('/channel/$encodedChannelId');
    return;
  }
  final name =
      joined.name.trim().isEmpty ? fallback.name.trim() : joined.name.trim();
  final query = name.isEmpty ? '' : '?name=${Uri.encodeQueryComponent(name)}';
  context.go('/channel/$encodedChannelId/conversation$query');
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
            child: Text(
              joining ? '处理中' : label,
              style: AppTheme.sans(
                size: 15,
                weight: FontWeight.w600,
                color: t.onAccent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelIntroPill extends StatelessWidget {
  const _ChannelIntroPill();

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: t.surfaceHover.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Text(
          '频道主Diana发布帖子，成员可评论和恢复',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.sans(
            size: 13,
            weight: FontWeight.w500,
            color: t.textMute.withValues(alpha: 0.56),
          ),
        ),
      ),
    );
  }
}

void _openRealChannelInfo(BuildContext context, ChannelInboxItem channel) {
  final channelId = channel.id.trim();
  if (channelId.isEmpty) return;
  final route = '/channel/${Uri.encodeComponent(channelId)}/info';
  try {
    context.push(route);
    return;
  } catch (_) {
    // Some widget tests mount the page without GoRouter.
  }
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ChannelInfoPage(channelId: channelId),
    ),
  );
}

void _showChannelMenu(BuildContext context, MockChannel channel) {
  final items = channel.isOwned
      ? const ['频道资料', '成员管理', '标签管理', '通知设置']
      : const ['频道资料', '通知设置', '退出频道'];
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: _channelModalBackground(context),
    showDragHandle: true,
    builder: (ctx) {
      final t = ctx.tk;
      return _ChannelModalSurface(
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in items)
                ListTile(
                  title: Text(
                    item,
                    style: AppTheme.sans(size: 15, color: t.text),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!context.mounted) return;
                      if (item == '频道资料') {
                        context.push(
                          '/channel/${Uri.encodeComponent(channel.id)}/info',
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
    },
  );
}

class _RealChannelPostCard extends StatefulWidget {
  const _RealChannelPostCard({
    required this.channel,
    required this.post,
    this.onOpen,
    this.onReaction,
    this.onRecall,
  });

  final ChannelInboxItem channel;
  final AsChannelPost post;
  final VoidCallback? onOpen;
  final Future<void> Function()? onReaction;
  final Future<void> Function()? onRecall;

  @override
  State<_RealChannelPostCard> createState() => _RealChannelPostCardState();
}

class _RealChannelPostCardState extends State<_RealChannelPostCard> {
  bool _expanded = false;
  bool _recalling = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final post = widget.post;
    final title = _postTitle(post.body);
    final excerpt = _postExcerpt(post.body, title);
    final author = post.authorName.trim().isEmpty
        ? _localpartFromMxid(post.authorId)
        : post.authorName.trim();
    return InkWell(
      onTap: widget.onOpen,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: t.text.withValues(alpha: 0.07),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PostListAvatar(label: author),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.sans(
                                size: 16,
                                weight: FontWeight.w600,
                                color: t.text,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const _PostTypeBadge(),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _formatPostTime(post.originServerTs),
                        style: AppTheme.sans(size: 12, color: t.textMute),
                      ),
                    ],
                  ),
                ),
                if (widget.onRecall != null) ...[
                  const SizedBox(width: 8),
                  _PostRecallButton(
                    key: ValueKey('channel_post_recall_${_realPostKey(post)}'),
                    busy: _recalling,
                    onTap: _recall,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.sans(
                size: 18,
                weight: FontWeight.w600,
                color: t.text,
              ).copyWith(height: 26 / 18),
            ),
            if (excerpt.isNotEmpty) ...[
              const SizedBox(height: 4),
              _ExpandablePostExcerpt(
                excerpt,
                expanded: _expanded,
                onToggle: () => setState(() => _expanded = !_expanded),
              ),
              const SizedBox(height: 10),
            ] else ...[
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                _PostCommentInput(onTap: widget.onOpen),
                const Spacer(),
                _PostStatButton(
                  key: ValueKey('channel_post_like_${_realPostKey(post)}'),
                  icon: Symbols.favorite,
                  active: post.reactedByMe,
                  count: post.reactionCount,
                  onTap: widget.onReaction == null
                      ? null
                      : () => widget.onReaction!(),
                ),
                const SizedBox(width: 16),
                _PostStatButton(
                  key: ValueKey('channel_post_comment_${_realPostKey(post)}'),
                  icon: Symbols.chat_bubble,
                  count: post.commentCount,
                  onTap: widget.onOpen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _recall() async {
    final onRecall = widget.onRecall;
    if (onRecall == null || _recalling) return;
    setState(() => _recalling = true);
    try {
      await onRecall();
    } finally {
      if (mounted) setState(() => _recalling = false);
    }
  }
}

class _PostRecallButton extends StatelessWidget {
  const _PostRecallButton({
    super.key,
    required this.busy,
    required this.onTap,
  });

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Tooltip(
      message: '删除帖子',
      child: Material(
        color: t.surfaceHover,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: busy ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox.square(
            dimension: 32,
            child: Center(
              child: busy
                  ? SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: t.danger,
                      ),
                    )
                  : Icon(
                      Symbols.delete,
                      size: 18,
                      color: t.danger,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PostListAvatar extends StatelessWidget {
  const _PostListAvatar({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: t.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        label.characters.isEmpty ? '' : label.characters.first,
        style: AppTheme.sans(
          size: 16,
          weight: FontWeight.w700,
          color: t.textMute,
        ),
      ),
    );
  }
}

class _PostTypeBadge extends StatelessWidget {
  const _PostTypeBadge();

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: t.accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '帖子',
        style: AppTheme.sans(
          size: 8,
          weight: FontWeight.w500,
          color: t.textMute,
        ).copyWith(height: 16 / 8),
      ),
    );
  }
}

class _ExpandablePostExcerpt extends StatelessWidget {
  const _ExpandablePostExcerpt(
    this.text, {
    required this.expanded,
    required this.onToggle,
  });

  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  static const _collapsedLines = 3;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final style = AppTheme.sans(
      size: 13,
      weight: FontWeight.w500,
      color: t.textMute,
    ).copyWith(height: 20 / 13);
    return LayoutBuilder(
      builder: (context, constraints) {
        final canExpand = _exceedsCollapsedLines(
          context,
          style,
          constraints.maxWidth,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              maxLines: expanded ? null : _collapsedLines,
              overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: style,
            ),
            if (canExpand) ...[
              const SizedBox(height: 10),
              _PostExpandControl(
                expanded: expanded,
                onTap: onToggle,
              ),
            ],
          ],
        );
      },
    );
  }

  bool _exceedsCollapsedLines(
    BuildContext context,
    TextStyle style,
    double maxWidth,
  ) {
    if (!maxWidth.isFinite || maxWidth <= 0) return false;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: _collapsedLines,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth);
    return painter.didExceedMaxLines;
  }
}

class _PostExpandControl extends StatelessWidget {
  const _PostExpandControl({
    required this.expanded,
    required this.onTap,
  });

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!expanded) ...[
              Container(width: 24, height: 1, color: t.border),
              const SizedBox(width: 6),
            ],
            Text(
              expanded ? '收起' : '展开更多',
              style: AppTheme.sans(
                size: 13,
                weight: FontWeight.w500,
                color: t.textMute,
              ).copyWith(height: 20 / 13),
            ),
            const SizedBox(width: 2),
            Icon(
              expanded
                  ? Symbols.keyboard_arrow_up
                  : Symbols.keyboard_arrow_down,
              size: 16,
              color: t.textMute,
            ),
          ],
        ),
      ),
    );
  }
}

class _PostCommentInput extends StatelessWidget {
  const _PostCommentInput({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 174,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: t.surfaceHover.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '输入评论...',
          style: AppTheme.sans(
            size: 13,
            weight: FontWeight.w500,
            color: t.textMute.withValues(alpha: 0.62),
          ).copyWith(height: 20 / 13),
        ),
      ),
    );
  }
}

class _PostStatButton extends StatelessWidget {
  const _PostStatButton({
    super.key,
    required this.icon,
    required this.count,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final int count;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 21,
              color: active ? t.danger : t.textMute,
              fill: active ? 1 : 0,
            ),
            const SizedBox(width: 5),
            Text(
              '$count',
              style: AppTheme.sans(
                size: 13,
                weight: FontWeight.w500,
                color: t.textMute,
              ).copyWith(height: 20 / 13),
            ),
          ],
        ),
      ),
    );
  }
}

String _postTitle(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return '我发布的帖子';
  final firstLine = trimmed.split(RegExp(r'[\r\n]')).first.trim();
  final sentenceEnd = firstLine.indexOf(RegExp(r'[。.!！?？]'));
  final candidate = sentenceEnd > 0
      ? firstLine.substring(0, sentenceEnd + 1).trim()
      : firstLine;
  if (candidate.characters.length <= 18) return candidate;
  return '${candidate.characters.take(18).toString()}...';
}

String _postExcerpt(
  String body,
  String title,
) {
  final trimmed = body.trim();
  if (trimmed.isEmpty || trimmed == title) return '';
  final normalized = trimmed.replaceAll(RegExp(r'\s+'), ' ');
  return normalized;
}

int _countFromLabel(String label) {
  final match = RegExp(r'\d+').firstMatch(label);
  if (match == null) return 0;
  return int.tryParse(match.group(0) ?? '') ?? 0;
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

class _ChannelPostCard extends StatefulWidget {
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
  State<_ChannelPostCard> createState() => _ChannelPostCardState();
}

class _ChannelPostCardState extends State<_ChannelPostCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final title = _postTitle(widget.post.body);
    final excerpt = _postExcerpt(widget.post.body, title);
    return InkWell(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        decoration: BoxDecoration(
          color: widget.selected ? t.accent.withValues(alpha: 0.12) : t.surface,
          borderRadius: BorderRadius.circular(20),
          border: widget.selected ? Border.all(color: t.accent) : null,
          boxShadow: [
            BoxShadow(
              color: t.text.withValues(alpha: 0.07),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.multiSelect) ...[
                  _ChannelSelectCheckmark(
                    selected: widget.selected,
                    onTap: widget.onTap,
                  ),
                  const SizedBox(width: 8),
                ],
                _PostListAvatar(label: widget.post.author),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.post.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.sans(
                                size: 16,
                                weight: FontWeight.w600,
                                color: t.text,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const _PostTypeBadge(),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        widget.post.timeLabel,
                        style: AppTheme.sans(size: 12, color: t.textMute),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.sans(
                size: 18,
                weight: FontWeight.w600,
                color: t.text,
              ).copyWith(height: 26 / 18),
            ),
            if (excerpt.isNotEmpty) ...[
              const SizedBox(height: 4),
              _ExpandablePostExcerpt(
                excerpt,
                expanded: _expanded,
                onToggle: () => setState(() => _expanded = !_expanded),
              ),
              const SizedBox(height: 10),
            ] else ...[
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                _PostCommentInput(onTap: widget.onTap),
                const Spacer(),
                _PostStatButton(
                  icon: Symbols.favorite,
                  count: _countFromLabel(widget.post.reactionLabel),
                ),
                const SizedBox(width: 16),
                _PostStatButton(
                  icon: Symbols.chat_bubble,
                  count: widget.post.commentCount,
                  onTap: widget.onTap,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelPostCreateFab extends StatelessWidget {
  const _ChannelPostCreateFab({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.accent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: 56,
          child: Icon(
            Symbols.add,
            size: 30,
            color: t.onAccent,
            weight: 700,
          ),
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
