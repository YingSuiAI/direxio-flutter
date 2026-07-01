import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../../l10n/app_localizations.dart';
import '../channel/channel_inbox_data.dart';
import '../channel/channel_join_debug_log.dart';
import '../channel/channel_join_flow.dart';
import '../channel/channel_post_content.dart';
import '../channel/channel_post_media.dart';
import '../chat/chat_record_forwarding.dart';
import '../chat/cached_thumbnail_image.dart';
import '../chat/product_media_outbox_flow.dart';
import '../channel/public_channel_target.dart';
import '../providers/as_bootstrap_store_provider.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_event_stream_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/channel_provider.dart';
import '../providers/matrix_media_cache_provider.dart';
import '../providers/media_thumbnail_cache_provider.dart';
import '../providers/product_conversations_provider.dart';
import '../providers/user_profile_directory_provider.dart';
import '../utils/contact_display_name.dart';
import '../utils/contact_identity_label.dart';
import '../utils/product_conversation_navigation.dart';
import '../utils/room_read_state.dart';
import '../utils/user_profile_directory.dart';
import '../widgets/m3/glass_header.dart';
import 'channel_info_page.dart';
import '../widgets/center_toast.dart';

class ChannelPage extends ConsumerStatefulWidget {
  const ChannelPage({super.key, required this.channelId});

  final String channelId;

  @override
  ConsumerState<ChannelPage> createState() => _ChannelPageState();
}

class _ChannelPageState extends ConsumerState<ChannelPage> {
  bool _multiSelect = false;
  final Set<String> _selected = {};
  bool _bootstrapRecoveryAttempted = false;
  bool _bootstrapRecoveryInFlight = false;

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

    if (_shouldRecoverRealChannel(ref, widget.channelId)) {
      unawaited(_recoverRealChannel());
      return const _ChannelLoadingScaffold();
    }

    return _PublicChannelScaffold(channelId: widget.channelId);
  }

  bool _shouldRecoverRealChannel(WidgetRef ref, String channelId) {
    if (_bootstrapRecoveryInFlight || _bootstrapRecoveryAttempted) {
      return false;
    }
    final auth = ref.watch(authStateNotifierProvider).valueOrNull;
    if (auth?.isLoggedIn != true) return false;
    final bootstrap = ref.watch(asSyncCacheProvider).bootstrap;
    if (_bootstrapHasChannel(bootstrap, channelId)) return false;
    return true;
  }

  Future<void> _recoverRealChannel() async {
    if (_bootstrapRecoveryInFlight) return;
    _bootstrapRecoveryInFlight = true;
    _bootstrapRecoveryAttempted = true;
    try {
      final repository = ref.read(asBootstrapRepositoryProvider);
      final currentUserId = ref.read(matrixClientProvider).userID;
      final cached = await repository.readCached();
      if (!mounted) return;
      if (cached != null && asBootstrapBelongsToUser(cached, currentUserId)) {
        ref.read(asSyncCacheProvider.notifier).update(
              (state) => state.copyWith(bootstrap: cached),
            );
        if (_bootstrapHasChannel(cached, widget.channelId)) return;
      }
      final bootstrap = await repository.refresh();
      if (!mounted) return;
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.copyWith(bootstrap: bootstrap),
          );
    } on Object catch (e) {
      debugPrint('channel bootstrap recovery failed: $e');
    } finally {
      _bootstrapRecoveryInFlight = false;
      if (mounted) setState(() {});
    }
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
      final l10n = _l10n(context);
      showTopSnackBar(
        context,
        SnackBar(content: Text(l10n?.chatRecordForwarded ?? '已转发聊天记录')),
      );
    } on Object catch (err) {
      if (!mounted) return;
      final l10n = _l10n(context);
      showTopSnackBar(
        context,
        SnackBar(
          content: Text(l10n?.chatRecordForwardFailed('$err') ?? '转发失败：$err'),
        ),
      );
    }
  }
}

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
  final productConversations =
      ref.watch(productConversationsProvider).valueOrNull ?? const [];
  final channels = ChannelInboxData.fromBootstrap(
    bootstrap,
    fallbackDomain: _domainFromRoomId(channelId) ?? 'p2p-im.com',
    productConversations: productConversations,
    roomNameForRoomId: (roomId) => _matrixRoomName(client, roomId),
    roomAvatarForRoomId: (roomId) => _matrixRoomAvatar(client, roomId),
  );
  for (final channel in channels) {
    if (channel.id == channelId || channel.roomId == channelId) return channel;
  }
  return null;
}

bool _bootstrapHasChannel(AsSyncBootstrap? bootstrap, String channelId) {
  final trimmed = channelId.trim();
  if (trimmed.isEmpty || bootstrap == null) return false;
  for (final channel in bootstrap.channels) {
    if (channel.channelId.trim() == trimmed ||
        channel.roomId.trim() == trimmed) {
      return true;
    }
  }
  return false;
}

class _ChannelLoadingScaffold extends StatelessWidget {
  const _ChannelLoadingScaffold();

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    return Scaffold(
      backgroundColor: _channelPageBackground(context),
      body: Column(
        children: [
          GlassHeader.detail(title: l10n?.channelFallbackTitle ?? '频道'),
          Expanded(
            child: Center(
              child: CircularProgressIndicator(color: context.tk.accent),
            ),
          ),
        ],
      ),
    );
  }
}

String? _domainFromRoomId(String roomId) {
  final domain = serverNameFromMatrixId(roomId);
  return domain.isEmpty ? null : domain;
}

String _matrixRoomName(Client client, String roomId) {
  final room = client.getRoomById(roomId.trim());
  if (room == null) return '';
  final name = safeRoomDisplayName(room).trim();
  return _looksLikeMatrixRoomId(name) ? '' : name;
}

String _matrixRoomAvatar(Client client, String roomId) {
  return client.getRoomById(roomId.trim())?.avatar?.toString() ?? '';
}

Color _channelPageBackground(BuildContext context) {
  return context.tk.bg;
}

AppLocalizations? _l10n(BuildContext context) {
  return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    final l10n = _l10n(context);
    final channel = widget.channel;
    final postsAsync = ref.watch(channelPostsProvider(channel.id));
    final posts = postsAsync.valueOrNull ?? const <AsChannelPost>[];
    final authorDirectory = ref.watch(userProfileDirectoryProvider);
    _markLatestPostRead(channel, posts);
    return Scaffold(
      backgroundColor: _channelPageBackground(context),
      floatingActionButton: !widget.multiSelect && channel.canCreatePost
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
            title: _postChannelTitle(
              channel.name,
              fallback: _l10n(context)?.channelFallbackTitle ?? '频道',
            ),
            titleTrailing: _channelTitleLock(context, channel.visibility),
            actions: [
              GlassHeaderButton(
                icon: Symbols.more_vert,
                onTap: () => _openRealChannelInfo(context, channel),
              ),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              color: context.tk.accent,
              onRefresh: _refreshChannelInfo,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 18),
                children: [
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
                          authorDirectory: authorDirectory,
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
                          canComment: channel.canCreateComment,
                          canReact: channel.canToggleReaction,
                        ),
                      )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 72),
                      child: _ChannelEmptyState(
                        icon: Symbols.campaign,
                        title: l10n?.channelPostEmptyTitle ?? '还没有频道内容',
                        subtitle: l10n?.channelPostEmptySubtitle ?? '发布后会显示在这里',
                      ),
                    ),
                ],
              ),
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

  Future<void> _refreshChannelInfo() async {
    final bootstrap = await ref.read(asBootstrapRepositoryProvider).refresh();
    if (!mounted) return;
    ref.read(asSyncCacheProvider.notifier).update(
          (state) => state.copyWith(bootstrap: bootstrap),
        );
    await ref.read(channelPostsProvider(widget.channel.id).notifier).refresh();
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
    final roomId = channel.roomId.trim();
    final readAt = latest.originServerTs > 0
        ? DateTime.fromMillisecondsSinceEpoch(
            latest.originServerTs,
            isUtc: true,
          )
        : DateTime.now().toUtc();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (roomId.isNotEmpty) {
        final room = ref.read(matrixClientProvider).getRoomById(roomId);
        if (room != null) {
          markRoomLocallyRead(room);
          if (room.client.isLogged() && room.client.homeserver != null) {
            unawaited(
              room.setReadMarker(eventId, mRead: eventId).catchError(
                (Object e) {
                  debugPrint('channel post Matrix read marker failed: $e');
                },
              ),
            );
          }
        }
        ref.read(asSyncCacheProvider.notifier).update(
              (state) => state.withRoomUnreadCleared(roomId, readAt: readAt),
            );
      }
      try {
        final realtime = ref.read(asEventStreamRefreshProvider);
        if (realtime != null) {
          await realtime.updateReadMarker(
            roomId,
            eventId,
            originServerTs: latest.originServerTs,
            action: 'channels.read_marker',
            channelId: channel.id,
          );
        } else {
          await ref.read(asClientProvider).updateChannelReadMarker(
                channel.id,
                eventId: eventId,
                originServerTs: latest.originServerTs,
              );
        }
      } catch (_) {
        try {
          await ref.read(asClientProvider).updateChannelReadMarker(
                channel.id,
                eventId: eventId,
                originServerTs: latest.originServerTs,
              );
        } catch (_) {
          // Read marker failure should not block the channel reader UI.
        }
      }
    });
  }

  bool _canRecallPost(ChannelInboxItem channel, AsChannelPost post) {
    return channel.canRecallPost && post.postId.trim().isNotEmpty;
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
      final l10n = _l10n(context);
      showTopSnackBar(
        context,
        SnackBar(content: Text(l10n?.channelPostDeleted ?? 'Post deleted')),
      );
    } catch (error) {
      if (!mounted) return;
      final l10n = _l10n(context);
      showTopSnackBar(
        context,
        SnackBar(
          content: Text(
            l10n?.channelPostDeleteFailed('$error') ??
                'Failed to delete post: $error',
          ),
        ),
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
      return client.getPublicChannelByRoomId(
        trimmed,
        remoteNodeBaseUri: publicBaseUriForMatrixRoomId(trimmed),
      );
    }
    return client.getPublicChannel(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    return FutureBuilder<AsChannel>(
      future: _future,
      builder: (context, snapshot) {
        final channel = snapshot.data;
        return Scaffold(
          backgroundColor: _channelPageBackground(context),
          body: Column(
            children: [
              GlassHeader.detail(
                title: channel == null
                    ? l10n?.channelFallbackTitle ?? '频道'
                    : _postChannelTitle(
                        channel.name,
                        fallback: l10n?.channelFallbackTitle ?? '频道',
                      ),
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
      final l10n = _l10n(context);
      return _ChannelEmptyState(
        icon: Symbols.search_off,
        title: l10n?.channelMissingTitle ?? '频道不存在',
        subtitle: l10n?.channelMissingSubtitle ??
            'This channel may be private, deleted, or temporarily unreachable.',
      );
    }
    final l10n = _l10n(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 72),
          child: _ChannelEmptyState(
            icon: Symbols.campaign,
            title: l10n?.channelNoPublicContentTitle ?? '还没有公开内容',
            subtitle: l10n?.channelNoPublicContentSubtitle ?? '加入频道后可以查看后续发布内容',
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
      final asClient = ref.read(asClientProvider);
      final joined = await asClient.joinChannelByRoomId(
        roomId,
        discoveredChannel: channel,
        remoteNodeBaseUri: publicBaseUriForMatrixRoomId(roomId),
      );
      if (!mounted) return;
      if (isAsChannelMemberJoinFailed(joined.memberStatus)) {
        setState(() {
          _joining = false;
          _future = Future.value(joined);
        });
        showTopSnackBar(
          context,
          SnackBar(
            content: Text(
              channelJoinStatusText(joined.memberStatus, l10n: _l10n(context)),
            ),
          ),
        );
        return;
      }
      if (!isAsChannelMemberJoined(joined.memberStatus)) {
        setState(() => _future = Future.value(joined));
        showTopSnackBar(
          context,
          SnackBar(
            content:
                Text(_channelJoinWaitingText(context, joined.memberStatus)),
          ),
        );
        final projected = await waitForJoinedChannelProjectionData(
          ref,
          channelId: joined.channelId.trim().isEmpty
              ? channel.channelId
              : joined.channelId.trim(),
          roomId: joined.roomId.trim().isEmpty ? roomId : joined.roomId.trim(),
        );
        if (!mounted) return;
        final resolved = projected;
        if (resolved == null) {
          setState(() => _joining = false);
          return;
        }
        setState(() {
          _joining = false;
          _future = Future.value(resolved);
        });
        _openJoinedPublicChannel(context, resolved, fallback: channel);
        return;
      }
      setState(() {
        _joining = false;
        _future = Future.value(joined);
      });
      final bootstrap = await ref.read(asBootstrapRepositoryProvider).refresh();
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.copyWith(bootstrap: bootstrap),
          );
      if (!mounted) return;
      _openJoinedPublicChannel(context, joined, fallback: channel);
    } catch (err) {
      logChannelJoinForbidden(
        err,
        source: 'channel_page',
        channelId: channel.channelId,
        roomId: roomId,
        remoteNodeBaseUri: publicBaseUriForMatrixRoomId(roomId),
        discoveredChannel: channel,
      );
      if (!mounted) return;
      setState(() => _joining = false);
      final l10n = _l10n(context);
      showTopSnackBar(
        context,
        SnackBar(
            content: Text(l10n?.channelJoinFailed('$err') ?? '加入频道失败：$err')),
      );
    }
  }
}

String _channelJoinWaitingText(BuildContext context, String status) {
  return channelJoinStatusText(status, l10n: _l10n(context));
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

String _postChannelTitle(String name, {String fallback = '频道'}) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return fallback;
  return trimmed.startsWith('#') ? trimmed.substring(1).trim() : trimmed;
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
        channelType: joined.channelType,
        name: joined.name.trim().isEmpty ? fallback.name : joined.name,
      ) ??
      channelConversationRoute(
        channelId,
        name: joined.name.trim().isEmpty ? fallback.name : joined.name,
      );
  context.go(route);
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
    final approved = status == asChannelMemberStatusApproved ||
        status == asChannelMemberStatusJoining;
    final failed = status == asChannelMemberStatusJoinFailed;
    final approval = channel.joinPolicy == asChannelJoinPolicyApproval;
    final l10n = _l10n(context);
    final label = joined
        ? l10n?.channelJoinJoined ?? 'Joined'
        : pending
            ? l10n?.channelJoinPending ?? '待审核'
            : approved
                ? l10n?.channelJoinSyncing ?? '同步中'
                : failed
                    ? l10n?.channelJoinRetry ?? '重新加入'
                    : approval
                        ? l10n?.channelJoinApply ?? '申请加入'
                        : l10n?.channelJoinAction ?? '加入频道';
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
            onPressed: joined || pending || approved || joining ? null : onJoin,
            child: Text(
              joining ? l10n?.channelJoinProcessing ?? '处理中' : label,
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

class _RealChannelPostCard extends StatefulWidget {
  const _RealChannelPostCard({
    required this.channel,
    required this.post,
    required this.authorDirectory,
    required this.canComment,
    required this.canReact,
    this.onOpen,
    this.onReaction,
    this.onRecall,
  });

  final ChannelInboxItem channel;
  final AsChannelPost post;
  final UserProfileDirectory authorDirectory;
  final bool canComment;
  final bool canReact;
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
    final l10n = _l10n(context);
    final post = widget.post;
    final body = channelPostBodyText(post);
    final images = channelPostImagesFromPost(post);
    final authorIdentity = widget.authorDirectory.resolve(
      userId: post.authorId,
      displayName: post.authorName,
      avatarUrl: post.authorAvatarUrl,
    );
    final author = authorIdentity.resolvedName.trim().isNotEmpty
        ? authorIdentity.resolvedName
        : _postAuthorLabel(post, l10n);
    final avatarUrl = _postListAvatarUrl(post, authorIdentity.avatarUrl);
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
                _PostListAvatar(
                  label: author,
                  imageUrl: avatarUrl.isEmpty ? null : avatarUrl,
                ),
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
            ChannelPostContent(
              images: images,
              body: body,
              expanded: _expanded,
              onToggle: () => setState(() => _expanded = !_expanded),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _PostCommentInput(
                  onTap: widget.canComment ? widget.onOpen : null,
                ),
                const Spacer(),
                _PostStatButton(
                  key: ValueKey('channel_post_like_${_realPostKey(post)}'),
                  icon: Symbols.favorite,
                  active: post.reactedByMe,
                  count: post.reactionCount,
                  onTap: !widget.canReact || widget.onReaction == null
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
    final l10n = _l10n(context);
    final t = context.tk;
    return Tooltip(
      message: l10n?.channelPostDeleteTooltip ?? 'Delete post',
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
  const _PostListAvatar({required this.label, this.imageUrl});

  final String label;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 40,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _PostListAvatarImage(label: label, imageUrl: imageUrl),
      ),
    );
  }
}

class _PostListAvatarImage extends ConsumerWidget {
  const _PostListAvatarImage({required this.label, this.imageUrl});

  final String label;
  final String? imageUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final url = imageUrl?.trim() ?? '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        key: ValueKey('channel_post_avatar_$url'),
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(t),
      );
    }
    final uri = Uri.tryParse(url);
    if (uri != null && uri.isScheme('mxc')) {
      return CachedThumbnailImage(
        key: ValueKey('channel_post_avatar_$url'),
        cacheKey: url,
        cache: ref.watch(mediaThumbnailCacheProvider).valueOrNull,
        cacheFuture: ref.read(mediaThumbnailCacheProvider.future),
        loadBytes: () => _loadMxcThumbnailBytes(ref, uri),
        fit: BoxFit.cover,
        loadingBuilder: (_) => _loading(t),
        failedBuilder: (_) => _fallback(t),
      );
    }
    return _fallback(t);
  }

  Future<Uint8List> _loadMxcThumbnailBytes(WidgetRef ref, Uri uri) async {
    final bytes = await ref
        .read(matrixMediaBytesCacheProvider)
        .read(ref.read(matrixClientProvider), uri);
    return localOutboxThumbnailBytes(bytes);
  }

  Widget _loading(PortalTokens t) {
    return Container(
      color: t.surfaceHigh,
      alignment: Alignment.center,
      child: SizedBox.square(
        dimension: 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: t.accent),
      ),
    );
  }

  Widget _fallback(PortalTokens t) {
    return Container(
      color: t.secondaryContainer,
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

String _postListAvatarUrl(
  AsChannelPost post,
  String resolvedAuthorAvatarUrl,
) {
  final resolved = resolvedAuthorAvatarUrl.trim();
  if (resolved.isNotEmpty) return resolved;
  return post.authorAvatarUrl.trim();
}

String _postAuthorLabel(AsChannelPost post, AppLocalizations? l10n) {
  final name = post.authorName.trim();
  if (name.isNotEmpty) return name;
  final localpart = _localpartFromMxid(post.authorId, l10n).trim();
  if (localpart.isNotEmpty) return localpart;
  return l10n?.commonUser ?? 'User';
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
        _l10n(context)?.channelPostType ?? 'Post',
        style: AppTheme.sans(
          size: 8,
          weight: FontWeight.w500,
          color: t.textMute,
        ).copyWith(height: 16 / 8),
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
    final l10n = _l10n(context);
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
          l10n?.channelPostCommentHint ?? '输入评论...',
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
            if (icon == Symbols.favorite)
              Image.asset(
                active ? 'assets/images/like.png' : 'assets/images/no-like.png',
                width: 21,
                height: 21,
              )
            else
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

String _localpartFromMxid(String mxid, AppLocalizations? l10n) {
  if (!mxid.startsWith('@')) {
    return mxid.trim().isEmpty ? l10n?.commonUser ?? 'User' : mxid.trim();
  }
  final colon = mxid.indexOf(':');
  final end = colon < 0 ? mxid.length : colon;
  return mxid.substring(1, end).trim().isEmpty
      ? l10n?.commonUser ?? 'User'
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
