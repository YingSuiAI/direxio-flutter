import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:intl/intl.dart';
import '../channel/channel_home_tab.dart';
import '../channel/create_channel_sheet.dart';
import '../providers/as_bootstrap_store_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/conversation_preferences_provider.dart';
import '../providers/friend_request_read_provider.dart';
import '../providers/conversation_summary_provider.dart';
import '../providers/home_hidden_conversations_provider.dart';
import '../providers/local_message_order_provider.dart';
import '../providers/local_outbox_provider.dart';
import '../providers/matrix_message_clients_provider.dart';
import '../providers/product_conversations_provider.dart';
import '../widgets/portal_avatar.dart';
import '../../data/as_client.dart';
import '../../data/conversation_summary_store.dart';
import '../../data/local_outbox_store.dart';
import '../../l10n/app_localizations.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../providers/app_warmup_provider.dart';
import '../providers/voice_call_provider.dart';
import '../call/voice_call_controller.dart';
import '../call/voice_call_display_name.dart';
import '../utils/avatar_url.dart';
import '../utils/group_creation_flow.dart';
import '../utils/message_preview.dart';
import '../utils/product_conversation_navigation.dart';
import '../widgets/app_glass_background.dart';
import '../widgets/m3/m3_search_field.dart';
import '../utils/contact_display_name.dart';
import '../utils/contact_identity_label.dart';
import '../utils/direct_contact_status.dart';
import 'me_home_tab.dart';

const _homeBg = Color(0xFFFAFAFA);
const _homeText = Color(0xFF262628);
const _homeMuted = Color(0xFFA3A3A4);
const _homeBorder = Color(0xFFE6E6E6);
const _conversationTileAvatarSize = 42.0;
const _iconMenuAddFriend = 'assets/icons/menu_add_friend.svg';
const _iconMenuCreateGroup = 'assets/icons/menu_create_group.svg';
const _iconMenuScan = 'assets/icons/menu_scan.svg';
const _iconTabChats = 'assets/icons/tab_chats.svg';
const _iconTabContacts = 'assets/icons/tab_contacts.svg';
const _iconTabChannel = 'assets/icons/tab_channel.svg';
const _iconTabMe = 'assets/icons/tab_me.svg';
const _iconBottomSearchTg = 'assets/icons/bottom_search_tg.svg';
const _assetMeTabNormal =
    'assets/resources/tab_profile_normal__Profile Square 2.png';
const _assetMeTabSelected =
    'assets/resources/tab_profile_selected__Profile Square 2.png';
const _bottomSearchTapSize = 56.0;
const _bottomSearchIconSize = 48.0;
const _asBootstrapRefreshExistingMinInterval = Duration(seconds: 8);

final asBootstrapLiveRefreshIntervalProvider = Provider<Duration?>(
  (ref) => const Duration(seconds: 10),
);

bool _homeDark(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark;
}

Color _homeBgColor(BuildContext context) {
  return _homeDark(context) ? context.tk.bg : _homeBg;
}

Color _homeTextColor(BuildContext context) {
  return _homeDark(context) ? context.tk.text : _homeText;
}

Color _homeMutedColor(BuildContext context) {
  return _homeDark(context) ? context.tk.textMute : _homeMuted;
}

Color _homeBorderColor(BuildContext context) {
  return _homeDark(context) ? context.tk.border : _homeBorder;
}

Color _homeTabColor(BuildContext context, {required bool active}) {
  if (_homeDark(context)) return context.tk.accent;
  return active ? context.tk.accent : _homeText;
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  int _tab = 0;
  StreamSubscription<SyncUpdate>? _syncSub;
  StreamSubscription<VoiceCallUiState>? _voiceCallSub;
  StreamSubscription<GroupCallUiState>? _groupCallSub;
  bool _resumeSyncInFlight = false;
  bool _asBootstrapRefreshInFlight = false;
  bool _asBootstrapRefreshScheduled = false;
  bool _staleBootstrapClearScheduled = false;
  Timer? _asBootstrapLiveRefreshTimer;
  Timer? _asBootstrapRefreshTimer;
  DateTime? _lastAsBootstrapRefreshAt;
  String? _lastBootstrapRefreshUserId;
  String? _lastHomeSyncSignature;
  String? _incomingCallRouteRoomId;
  String? _incomingGroupCallRouteRoomId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 订阅 client.onSync, 但只在会话列表关心的数据变化时重建。
    // Matrix 的空 sync 很频繁，不能让它们触发整页刷新。
    final client = ref.read(matrixClientProvider);
    _lastHomeSyncSignature = _homeSyncSignature(client);
    _attachVoiceCallController(client);
    _syncSub = client.onSync.stream.listen((_) {
      _refreshHomeAfterMatrixSync(client);
      scheduleMicrotask(() => _refreshHomeAfterMatrixSync(client));
    });
    unawaited(ref.read(appWarmupProvider.future));
    _startAsBootstrapLiveRefresh();
  }

  void _refreshHomeAfterMatrixSync(Client client) {
    if (!mounted) return;
    final agentMxid = portalAgentMxidForClient(client);
    final auth = ref.read(authStateNotifierProvider).valueOrNull;
    final syncCache = asSyncCacheForUser(
      ref.read(asSyncCacheProvider),
      client.userID ?? auth?.userId,
    );
    final needsClassification = _hasUnclassifiedJoinedRooms(
      client: client,
      syncCache: syncCache,
      agentMxid: agentMxid,
    );
    final hasPendingInvite = _hasPendingInviteRooms(
      client: client,
      agentMxid: agentMxid,
    );
    _showHiddenHomeConversationsWithUnread(client, syncCache);
    _scheduleAsBootstrapRefreshIfNeeded(
      refreshExisting: true,
      force: needsClassification || hasPendingInvite,
    );
    final nextSignature = _homeSyncSignature(client);
    if (nextSignature == _lastHomeSyncSignature) return;
    _lastHomeSyncSignature = nextSignature;
    ref.invalidate(productConversationsProvider);
    setState(() {});
  }

  void _showHiddenHomeConversationsWithUnread(
    Client client,
    AsSyncCacheState syncCache,
  ) {
    final hidden = ref.read(homeHiddenConversationIdsProvider);
    if (hidden.isEmpty) return;
    final unreadRoomIds = <String>{};
    for (final room in client.rooms) {
      final roomId = room.id.trim();
      if (roomId.isEmpty || !hidden.contains(roomId)) continue;
      if (conversationUnreadCount(matrixUnreadCount: room.notificationCount) >
          0) {
        unreadRoomIds.add(roomId);
      }
    }
    for (final room
        in syncCache.bootstrap?.rooms ?? const <AsSyncRoomSummary>[]) {
      final roomId = room.roomId.trim();
      if (hidden.contains(roomId) && room.unreadCount > 0) {
        unreadRoomIds.add(roomId);
      }
    }
    for (final group
        in syncCache.bootstrap?.groups ?? const <AsSyncRoomSummary>[]) {
      final roomId = group.roomId.trim();
      if (hidden.contains(roomId) && group.unreadCount > 0) {
        unreadRoomIds.add(roomId);
      }
    }
    if (unreadRoomIds.isEmpty) return;
    for (final roomId in unreadRoomIds) {
      showHomeConversation(ref, roomId);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncSub?.cancel();
    _voiceCallSub?.cancel();
    _groupCallSub?.cancel();
    _asBootstrapLiveRefreshTimer?.cancel();
    _asBootstrapRefreshTimer?.cancel();
    super.dispose();
  }

  void _startAsBootstrapLiveRefresh() {
    final interval = ref.read(asBootstrapLiveRefreshIntervalProvider);
    if (interval == null || interval <= Duration.zero) return;
    _asBootstrapLiveRefreshTimer?.cancel();
    _asBootstrapLiveRefreshTimer = Timer.periodic(interval, (_) {
      if (!mounted) return;
      _scheduleAsBootstrapRefreshIfNeeded(
        refreshExisting: true,
        force: true,
      );
    });
  }

  void _attachVoiceCallController(Client client) {
    if (!client.isLogged()) return;
    final controller = ref.read(voiceCallControllerProvider);
    _voiceCallSub ??= controller.stateStream.listen(_handleVoiceCallState);
    _groupCallSub ??= controller.groupStateStream.listen(_handleGroupCallState);
    unawaited(controller.attachClient(client));
  }

  void _handleVoiceCallState(VoiceCallUiState state) {
    if (!mounted) return;
    if (!state.isActive) {
      _incomingCallRouteRoomId = null;
      return;
    }
    if (!p2pIncomingCallCanOpenRoute(
      state,
      currentRouteRoomId: _incomingCallRouteRoomId,
    )) {
      return;
    }
    final roomId = state.roomId!;
    _incomingCallRouteRoomId = roomId;
    final syncCache = ref.read(asSyncCacheProvider);
    final contact = state.peerUserId == null
        ? syncCache.contactForRoom(roomId)
        : syncCache.contactForUserId(state.peerUserId!) ??
            syncCache.contactForRoom(roomId);
    final room = ref.read(matrixClientProvider).getRoomById(roomId);
    final displayName = voiceCallPeerDisplayName(
      peerMxid: state.peerUserId,
      contactDisplayName: contact?.displayName ?? '',
      contactDomain: contact?.domain ?? '',
      statePeerName: state.peerName,
      roomDisplayName: room?.getLocalizedDisplayname(),
    );
    final peerQuery = state.peerUserId == null
        ? ''
        : '&peer=${Uri.encodeQueryComponent(state.peerUserId!)}';
    final callQuery = state.callId == null
        ? ''
        : '&call_id=${Uri.encodeQueryComponent(state.callId!)}';
    final nameQuery = '&name=${Uri.encodeQueryComponent(displayName)}';
    final path = state.isVideo ? 'video-call' : 'call';
    final route =
        '/$path/${Uri.encodeComponent(roomId)}?incoming=1$peerQuery$callQuery$nameQuery';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.push(route);
    });
  }

  void _handleGroupCallState(GroupCallUiState state) {
    if (!mounted) return;
    if (!state.isActive) {
      _incomingGroupCallRouteRoomId = null;
      return;
    }
    if (!p2pIncomingGroupCallCanOpenRoute(
      state,
      currentRouteRoomId: _incomingGroupCallRouteRoomId,
    )) {
      return;
    }
    final roomId = state.roomId!;
    _incomingGroupCallRouteRoomId = roomId;
    final room = ref.read(matrixClientProvider).getRoomById(roomId);
    final roomName = state.roomName?.trim().isNotEmpty == true
        ? state.roomName!.trim()
        : room?.getLocalizedDisplayname() ?? '群聊';
    final callQuery = state.callId == null
        ? ''
        : '&call_id=${Uri.encodeQueryComponent(state.callId!)}';
    final nameQuery = '&name=${Uri.encodeQueryComponent(roomName)}';
    final path = state.isVideo ? 'group-video-call' : 'group-call';
    final route =
        '/$path/${Uri.encodeComponent(roomId)}?incoming=1$callQuery$nameQuery';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.push(route);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _scheduleResumeSync();
  }

  void _scheduleResumeSync() {
    if (_resumeSyncInFlight) return;
    final auth = ref.read(authStateNotifierProvider).valueOrNull;
    final client = ref.read(matrixClientProvider);
    if (!(auth?.isLoggedIn ?? false) || !client.isLogged()) return;

    _resumeSyncInFlight = true;
    unawaited(_refreshAfterResume(client));
  }

  Future<void> _refreshAfterResume(Client client) async {
    try {
      await client.oneShotSync().timeout(const Duration(seconds: 12));
      _scheduleAsBootstrapRefreshIfNeeded(refreshExisting: true);
    } catch (e) {
      debugPrint('Matrix resume sync failed: $e');
    } finally {
      _resumeSyncInFlight = false;
      if (mounted) setState(() {});
    }
  }

  void _scheduleAsBootstrapRefreshIfNeeded({
    bool refreshExisting = false,
    bool force = false,
  }) {
    if (_asBootstrapRefreshInFlight) return;
    if (_asBootstrapRefreshScheduled ||
        (_asBootstrapRefreshTimer?.isActive ?? false)) {
      return;
    }
    if (refreshExisting && !force) {
      final refreshedAt = _lastAsBootstrapRefreshAt;
      if (refreshedAt != null &&
          DateTime.now().difference(refreshedAt) <
              _asBootstrapRefreshExistingMinInterval) {
        return;
      }
    }
    final auth = ref.read(authStateNotifierProvider).valueOrNull;
    if (!(auth?.isLoggedIn ?? false)) return;
    final currentUserId = ref.read(matrixClientProvider).userID ?? auth?.userId;
    final cachedBootstrap = ref.read(asSyncCacheProvider).bootstrap;
    if (!asBootstrapBelongsToUser(cachedBootstrap, currentUserId)) {
      _scheduleStaleBootstrapClear();
    } else if (!refreshExisting && cachedBootstrap != null) {
      return;
    }
    if (!refreshExisting &&
        cachedBootstrap == null &&
        _lastBootstrapRefreshUserId == currentUserId) {
      return;
    }

    if (!refreshExisting) {
      _asBootstrapRefreshScheduled = true;
      scheduleMicrotask(() {
        _asBootstrapRefreshScheduled = false;
        if (!mounted || _asBootstrapRefreshInFlight) return;
        _asBootstrapRefreshInFlight = true;
        _lastAsBootstrapRefreshAt = DateTime.now();
        unawaited(_refreshAsBootstrap());
      });
      return;
    }

    _asBootstrapRefreshTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted || _asBootstrapRefreshInFlight) return;
      _asBootstrapRefreshInFlight = true;
      _lastAsBootstrapRefreshAt = DateTime.now();
      unawaited(_refreshAsBootstrap());
    });
  }

  void _finishAsBootstrapRefresh() {
    _asBootstrapRefreshInFlight = false;
  }

  Future<void> _refreshAsBootstrap() async {
    final refreshUserId = ref.read(matrixClientProvider).userID ??
        ref.read(authStateNotifierProvider).valueOrNull?.userId;
    try {
      final bootstrap = await ref
          .read(asBootstrapRepositoryProvider)
          .refresh()
          .timeout(const Duration(seconds: 10));
      final currentUserId = ref.read(matrixClientProvider).userID ??
          ref.read(authStateNotifierProvider).valueOrNull?.userId;
      if (!asBootstrapBelongsToUser(bootstrap, currentUserId)) {
        debugPrint(
          'home ignored bootstrap for ${bootstrap.user.userId}; '
          'current user is $currentUserId',
        );
        return;
      }
      _lastBootstrapRefreshUserId = null;
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.copyWith(bootstrap: bootstrap),
          );
      ref.invalidate(productConversationsProvider);
      if (mounted) setState(() {});
    } catch (e) {
      _lastBootstrapRefreshUserId = refreshUserId;
      debugPrint('home bootstrap refresh failed: $e');
    } finally {
      _finishAsBootstrapRefresh();
    }
  }

  void _scheduleStaleBootstrapClear() {
    if (_staleBootstrapClearScheduled) return;
    _staleBootstrapClearScheduled = true;
    scheduleMicrotask(() {
      _staleBootstrapClearScheduled = false;
      if (!mounted) return;
      final currentUserId = ref.read(matrixClientProvider).userID ??
          ref.read(authStateNotifierProvider).valueOrNull?.userId;
      final cachedBootstrap = ref.read(asSyncCacheProvider).bootstrap;
      if (asBootstrapBelongsToUser(cachedBootstrap, currentUserId)) return;
      ref.read(asSyncCacheProvider.notifier).state = const AsSyncCacheState();
    });
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(matrixClientProvider);
    final authState = ref.watch(authStateNotifierProvider);
    final syncCache = asSyncCacheForUser(
      ref.watch(asSyncCacheProvider),
      client.userID ?? authState.valueOrNull?.userId,
    );
    final friendRequestReadState = ref.watch(friendRequestReadProvider);
    final friendRequestUnreadCount = friendRequestReadState
        .unreadCountForRoomIds(_pendingFriendRequestRoomIds(
      client: client,
      syncCache: syncCache,
    ));
    final t = context.tk;
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    if (authState.valueOrNull?.isLoggedIn ?? false) {
      _scheduleAsBootstrapRefreshIfNeeded();
      _attachVoiceCallController(client);
    }

    final unreadTotal = _homeUnreadTotal(client, syncCache);

    return Scaffold(
      backgroundColor: _homeBgColor(context),
      body: Column(
        children: [
          if (_tab == 0)
            _ChatsTopBar(
              title: _homeTabTitle(l10n, 0),
              unreadCount: unreadTotal,
              onPlusTap: () => _handleHomePlusTap(context, ref),
            )
          else if (_tab == 1)
            _HomeTitleTopBar(
              title: _homeTabTitle(l10n, _tab),
              onPlusTap: () => _handleHomePlusTap(context, ref),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, c) {
                final wide = c.maxWidth >= 900;
                final pane = switch (_tab) {
                  0 => _ChatList(client: client),
                  1 => _ContactList(client: client),
                  2 => const ChannelExplorePage(),
                  _ => MePage(client: client),
                };
                if (!wide) return pane;
                return Row(
                  children: [
                    SizedBox(width: 340, child: pane),
                    VerticalDivider(width: 1, color: t.border),
                    Expanded(
                      child: _DetailPlaceholder(
                        tabTitle: _homeTabTitle(l10n, _tab),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _HomeBottomBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        onSearchTap: () => context.push('/search'),
        items: [
          const _HomeNavItem(
            iconAsset: _iconTabChats,
            labelIndex: 0,
            iconSize: 21,
          ),
          _HomeNavItem(
            iconAsset: _iconTabContacts,
            labelIndex: 1,
            badge: friendRequestUnreadCount > 0
                ? _formatBadgeCount(friendRequestUnreadCount)
                : null,
          ),
          const _HomeNavItem(
            iconAsset: _iconTabChannel,
            labelIndex: 2,
          ),
          const _HomeNavItem(
            iconAsset: _iconTabMe,
            activeIconAsset: _assetMeTabSelected,
            inactiveIconAsset: _assetMeTabNormal,
            labelIndex: 3,
          ),
        ],
      ),
    );
  }
}

class _HomeTitleTopBar extends StatelessWidget {
  const _HomeTitleTopBar({
    required this.title,
    required this.onPlusTap,
  });

  final String title;
  final VoidCallback onPlusTap;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final textColor = context.tk.text;
    return Container(
      height: topInset + 56,
      padding: EdgeInsets.fromLTRB(16, topInset + 4, 16, 4),
      color: _homeBgColor(context),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(right: 48),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left,
                style: AppTheme.sans(
                  size: 24,
                  weight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _GlassCircleButton(
              key: const ValueKey('chat_input_plus_circle'),
              icon: Symbols.add,
              size: 40,
              iconSize: 24,
              onTap: onPlusTap,
            ),
          ),
        ],
      ),
    );
  }
}

String _homeTabTitle(AppLocalizations? l10n, int index) {
  return switch (index) {
    0 => l10n?.tabChats ?? '消息',
    1 => l10n?.tabContacts ?? '通讯录',
    2 => l10n?.tabChannels ?? '频道',
    3 => l10n?.tabMe ?? '我的',
    _ => '',
  };
}

int _homeUnreadTotal(Client client, AsSyncCacheState syncCache) {
  final unreadByRoomId = <String, int>{};

  void merge(String roomId, int count) {
    final trimmed = roomId.trim();
    if (trimmed.isEmpty || count <= 0) return;
    final current = unreadByRoomId[trimmed] ?? 0;
    if (count > current) unreadByRoomId[trimmed] = count;
  }

  for (final room in client.rooms) {
    if (room.membership == Membership.join) {
      merge(
        room.id,
        conversationUnreadCount(matrixUnreadCount: room.notificationCount),
      );
    }
  }
  for (final room
      in syncCache.bootstrap?.rooms ?? const <AsSyncRoomSummary>[]) {
    merge(room.roomId, room.unreadCount);
  }
  for (final group
      in syncCache.bootstrap?.groups ?? const <AsSyncRoomSummary>[]) {
    merge(group.roomId, group.unreadCount);
  }
  return unreadByRoomId.values.fold<int>(0, (total, count) => total + count);
}

String _homeSyncSignature(Client client) {
  final rooms = client.rooms.toList(growable: false)
    ..sort((a, b) => a.id.compareTo(b.id));
  final parts = <String>[client.userID ?? ''];
  for (final room in rooms) {
    final lastEvent = room.lastEvent;
    parts.add(
      [
        room.id,
        room.membership.name,
        lastEvent?.eventId ?? '',
        lastEvent?.type ?? '',
        lastEvent?.originServerTs.millisecondsSinceEpoch.toString() ?? '',
        room.notificationCount.toString(),
        room.highlightCount.toString(),
        _roomMemberProfileSignature(client, room),
      ].join(','),
    );
  }
  return parts.join('|');
}

String _roomMemberProfileSignature(Client client, Room room) {
  final users = room.getParticipants()..sort((a, b) => a.id.compareTo(b.id));
  return users.map((user) {
    final avatar = matrixContentHttpUrl(client, user.avatarUrl) ?? '';
    final displayName = user.displayName?.trim() ?? '';
    return '${user.id}:$displayName:$avatar';
  }).join(';');
}

class _ChatsTopBar extends StatelessWidget {
  const _ChatsTopBar({
    required this.title,
    required this.unreadCount,
    required this.onPlusTap,
  });

  final String title;
  final int unreadCount;
  final VoidCallback onPlusTap;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final label = unreadCount > 0 ? '$title($unreadCount)' : title;
    final textColor = context.tk.text;
    return Container(
      height: topInset + 56,
      padding: EdgeInsets.fromLTRB(16, topInset + 4, 16, 4),
      color: _homeBgColor(context),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(right: 48),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left,
                style: AppTheme.sans(
                  size: 24,
                  weight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _GlassCircleButton(
              key: const ValueKey('chat_input_plus_circle'),
              icon: Symbols.add,
              size: 40,
              iconSize: 25,
              onTap: onPlusTap,
            ),
          ),
        ],
      ),
    );
  }
}

List<String> _pendingFriendRequestRoomIds({
  required Client client,
  required AsSyncCacheState syncCache,
}) {
  final agentMxid = portalAgentMxidForClient(client);
  final roomIds = <String>{
    for (final room in client.rooms)
      if (isIncomingDirectContactInvite(room, agentMxid: agentMxid) &&
          room.id.trim().isNotEmpty)
        room.id.trim(),
    for (final contact in syncCache.pendingInboundContacts)
      if (contact.roomId.trim().isNotEmpty) contact.roomId.trim(),
    for (final request in syncCache.bootstrap?.pending.friendRequests ??
        const <AsSyncPendingItem>[])
      if (request.id.trim().isNotEmpty) request.id.trim(),
  };
  return roomIds.toList(growable: false);
}

String _formatBadgeCount(int count) => count > 99 ? '99+' : '$count';

enum _PlusAction { contact, group, channel, scan }

Future<void> _handleHomePlusTap(BuildContext context, WidgetRef ref) async {
  final action = await _showHomePlusMenu(context);
  if (action == null || !context.mounted) return;
  switch (action) {
    case _PlusAction.contact:
      context.push('/add-contact');
    case _PlusAction.group:
      showCreateGroupFlow(context, ref);
    case _PlusAction.channel:
      showCreateChannelDialog(context, ref);
    case _PlusAction.scan:
      context.push('/scan');
  }
}

Future<_PlusAction?> _showHomePlusMenu(BuildContext context) {
  final padding = MediaQuery.of(context).viewPadding;
  return showGeneralDialog<_PlusAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'home-plus-menu',
    barrierColor: Colors.black.withValues(alpha: 0.06),
    transitionDuration: const Duration(milliseconds: 130),
    pageBuilder: (context, _, __) {
      return Stack(
        children: [
          Positioned(
            top: padding.top + 53,
            right: 15,
            width: 126,
            height: 158,
            child: const _HomePlusMenuPanel(),
          ),
        ],
      );
    },
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _HomePlusMenuPanel extends StatelessWidget {
  const _HomePlusMenuPanel();

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final isDark = _homeDark(context);
    final panelColor =
        (isDark ? t.surfaceHigh : t.surface).withValues(alpha: 0.86);
    final borderColor =
        (isDark ? t.border : t.surface).withValues(alpha: isDark ? 0.9 : 1);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          key: const ValueKey('home_plus_menu_panel'),
          decoration: BoxDecoration(
            color: panelColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.12),
                blurRadius: 36,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: const Material(
            color: Colors.transparent,
            child: Padding(
              padding: EdgeInsets.only(top: 15),
              child: Column(
                children: [
                  _PlusMenuTile(
                    iconAsset: _iconMenuAddFriend,
                    label: '添加好友',
                    value: _PlusAction.contact,
                  ),
                  _PlusMenuTile(
                    iconAsset: _iconMenuCreateGroup,
                    label: '创建群聊',
                    value: _PlusAction.group,
                  ),
                  _PlusMenuTile(
                    iconAsset: _iconTabChannel,
                    label: '创建频道',
                    value: _PlusAction.channel,
                  ),
                  _PlusMenuTile(
                    iconAsset: _iconMenuScan,
                    label: '扫一扫',
                    value: _PlusAction.scan,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlusMenuTile extends StatelessWidget {
  const _PlusMenuTile({
    required this.iconAsset,
    required this.label,
    required this.value,
  });

  final String iconAsset;
  final String label;
  final _PlusAction value;

  @override
  Widget build(BuildContext context) {
    final textColor = _homeTextColor(context);
    return InkWell(
      onTap: () => Navigator.of(context).pop(value),
      child: SizedBox(
        height: 32,
        child: Row(
          children: [
            const SizedBox(width: 20),
            _DesignAssetIcon(
              assetName: iconAsset,
              size: 20,
              color: textColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.sans(
                  size: 14,
                  weight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeNavItem {
  const _HomeNavItem({
    required this.iconAsset,
    required this.labelIndex,
    this.badge,
    this.activeIconAsset,
    this.inactiveIconAsset,
    this.iconSize = 24,
  });

  final String iconAsset;
  final int labelIndex;
  final String? badge;
  final String? activeIconAsset;
  final String? inactiveIconAsset;
  final double iconSize;

  @override
  bool operator ==(Object other) {
    return other is _HomeNavItem &&
        other.iconAsset == iconAsset &&
        other.labelIndex == labelIndex &&
        other.badge == badge &&
        other.activeIconAsset == activeIconAsset &&
        other.inactiveIconAsset == inactiveIconAsset &&
        other.iconSize == iconSize;
  }

  @override
  int get hashCode => Object.hash(
        iconAsset,
        labelIndex,
        badge,
        activeIconAsset,
        inactiveIconAsset,
        iconSize,
      );
}

class _HomeBottomBar extends StatefulWidget {
  const _HomeBottomBar({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.onSearchTap,
  });

  final List<_HomeNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onSearchTap;

  @override
  State<_HomeBottomBar> createState() => _HomeBottomBarState();
}

class _HomeBottomBarState extends State<_HomeBottomBar> {
  Widget? _cached;
  int? _cachedIndex;
  List<_HomeNavItem>? _cachedItems;
  Brightness? _cachedBrightness;
  Locale? _cachedLocale;
  double? _cachedBottomInset;

  bool _itemsEqual(List<_HomeNavItem>? a, List<_HomeNavItem> b) {
    if (a == null || a.length != b.length) return false;
    for (var i = 0; i < b.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final locale = Localizations.localeOf(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    if (_cached != null &&
        _cachedIndex == widget.currentIndex &&
        _cachedBrightness == brightness &&
        _cachedLocale == locale &&
        _cachedBottomInset == bottomInset &&
        _itemsEqual(_cachedItems, widget.items)) {
      return _cached!;
    }
    _cachedIndex = widget.currentIndex;
    _cachedBrightness = brightness;
    _cachedLocale = locale;
    _cachedBottomInset = bottomInset;
    _cachedItems = List<_HomeNavItem>.of(widget.items);
    return _cached = _buildBar(context, bottomInset: bottomInset);
  }

  Widget _buildBar(BuildContext context, {required double bottomInset}) {
    final bg = _homeBgColor(context);
    return RepaintBoundary(
      child: SizedBox(
        height: 80 + bottomInset,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        bg.withValues(alpha: 0.0),
                        bg.withValues(alpha: _homeDark(context) ? 0.98 : 0.92),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 11,
              bottom: bottomInset + 5,
              width: 291,
              height: 56,
              child: _LiquidTabPill(
                items: widget.items,
                currentIndex: widget.currentIndex,
                onTap: widget.onTap,
              ),
            ),
            Positioned(
              right: 16,
              bottom: bottomInset + 4,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onSearchTap,
                child: SizedBox(
                  width: _bottomSearchTapSize,
                  height: _bottomSearchTapSize,
                  child: Center(
                    child: SvgPicture.asset(
                      _iconBottomSearchTg,
                      width: _bottomSearchIconSize,
                      height: _bottomSearchIconSize,
                      colorFilter: _homeDark(context)
                          ? ColorFilter.mode(context.tk.accent, BlendMode.srcIn)
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiquidTabPill extends StatelessWidget {
  const _LiquidTabPill({
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<_HomeNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final isDark = _homeDark(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark
            ? t.surfaceHigh.withValues(alpha: 0.92)
            : t.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(276),
        border: Border.all(
          color: isDark
              ? t.border.withValues(alpha: 0.28)
              : t.surfaceHigh.withValues(alpha: 0.72),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final active = index == currentIndex;
            final label = _homeTabTitle(l10n, item.labelIndex);
            return Expanded(
              child: SizedBox(
                height: 49,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => onTap(index),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (active)
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: _homeDark(context)
                                    ? t.accent.withValues(alpha: 0.13)
                                    : Colors.white.withValues(alpha: 0.76),
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 12,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              _DesignAssetIcon(
                                assetName: active
                                    ? item.activeIconAsset ?? item.iconAsset
                                    : item.inactiveIconAsset ?? item.iconAsset,
                                size: item.iconSize,
                                color: _homeTabColor(context, active: active),
                              ),
                              if (item.badge != null)
                                Positioned(
                                  key: ValueKey('bottom_nav_badge_$label'),
                                  top: -5,
                                  right: -9,
                                  child: _ConversationUnreadBadge(
                                    count: int.tryParse(item.badge!) ?? 1,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.sans(
                              size: 10,
                              weight: FontWeight.w600,
                              color: _homeTabColor(context, active: active),
                            ).copyWith(height: 1.2),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _DesignAssetIcon extends StatelessWidget {
  const _DesignAssetIcon({
    required this.assetName,
    required this.size,
    this.color,
  });

  final String assetName;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return _assetIcon(assetName, size: size, color: color);
  }
}

Widget _assetIcon(String assetName, {required double size, Color? color}) {
  return _SafeAssetIcon(assetName: assetName, size: size, color: color);
}

final Map<String, Future<ByteData>> _assetLoadFutures = {};
final Map<String, ByteData> _assetByteCache = {};
final Set<String> _assetLoadFailures = {};

Future<ByteData> _loadAssetBytes(String assetName) {
  return _assetLoadFutures.putIfAbsent(assetName, () async {
    try {
      final data = await rootBundle.load(assetName);
      _assetByteCache[assetName] = data;
      return data;
    } catch (_) {
      _assetLoadFailures.add(assetName);
      rethrow;
    }
  });
}

class _SafeAssetIcon extends StatelessWidget {
  const _SafeAssetIcon({
    required this.assetName,
    required this.size,
    this.color,
  });

  final String assetName;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (_assetLoadFailures.contains(assetName)) {
      final iconColor = color ?? context.tk.textMute;
      return Icon(
        _fallbackIconForAsset(assetName),
        size: size,
        color: iconColor,
      );
    }
    final cached = _assetByteCache[assetName];
    if (cached != null) {
      return _loadedAssetIcon(assetName, size: size, color: color);
    }
    return FutureBuilder<ByteData>(
      future: _loadAssetBytes(assetName),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final iconColor = color ?? context.tk.textMute;
          return Icon(
            _fallbackIconForAsset(assetName),
            size: size,
            color: iconColor,
          );
        }
        if (!snapshot.hasData) {
          return SizedBox.square(dimension: size);
        }
        return _loadedAssetIcon(assetName, size: size, color: color);
      },
    );
  }
}

Widget _loadedAssetIcon(String assetName,
    {required double size, Color? color}) {
  if (assetName.toLowerCase().endsWith('.svg')) {
    return SvgPicture.asset(
      assetName,
      width: size,
      height: size,
      fit: BoxFit.contain,
      colorFilter:
          color == null ? null : ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  final image = Image.asset(
    assetName,
    width: size,
    height: size,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
  );
  if (color == null) return image;
  return ColorFiltered(
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    child: image,
  );
}

IconData _fallbackIconForAsset(String assetName) {
  if (assetName.contains('me_channel') || assetName.contains('channel')) {
    return Symbols.forum;
  }
  if (assetName.contains('qr')) return Symbols.qr_code;
  if (assetName.contains('favorite')) return Symbols.favorite;
  if (assetName.contains('verification')) return Symbols.verified_user;
  if (assetName.contains('clear')) return Symbols.delete_sweep;
  if (assetName.contains('setting')) return Symbols.settings;
  if (assetName.contains('more')) return Symbols.more_vert;
  if (assetName.contains('back')) return Symbols.arrow_back;
  if (assetName.contains('emoji')) return Symbols.emoji_emotions;
  if (assetName.contains('plus') || assetName.contains('add')) {
    return Symbols.add;
  }
  return Symbols.image;
}

class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.size,
    required this.iconSize,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final textColor = _homeTextColor(context);
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: AppGlassPanel(
          borderRadius: BorderRadius.circular(size / 2),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: iconSize, color: textColor),
          ),
        ),
      ),
    );
  }
}

class _GroupAvatarGrid extends StatelessWidget {
  const _GroupAvatarGrid({required this.seed, this.imageUrl});

  final String seed;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      return PortalAvatar(
        seed: seed,
        size: _conversationTileAvatarSize,
        imageUrl: imageUrl,
        shape: AvatarShape.squircle,
      );
    }
    final colors = [
      const Color(0xFFE6F0FF),
      const Color(0xFFDFF7E7),
      const Color(0xFFFFE4E0),
      const Color(0xFFFFF0C7),
    ];
    return Container(
      width: _conversationTileAvatarSize,
      height: _conversationTileAvatarSize,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFC),
        borderRadius: BorderRadius.circular(4.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF17688B).withValues(alpha: 0.12),
            blurRadius: 1.4,
          ),
        ],
      ),
      padding: const EdgeInsets.all(1.4),
      child: Wrap(
        spacing: 1.4,
        runSpacing: 1.4,
        children: [
          for (var i = 0; i < 4; i++)
            Container(
              width: 18.9,
              height: 18.9,
              decoration: BoxDecoration(
                color: colors[(seed.hashCode + i).abs() % colors.length],
                borderRadius: BorderRadius.circular(2.8),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatList extends ConsumerWidget {
  const _ChatList({required this.client});
  final Client client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = client.rooms;
    final authState = ref.watch(authStateNotifierProvider);
    final isAuthLoading = authState.isLoading && authState.valueOrNull == null;
    final currentUserId = client.userID ?? authState.valueOrNull?.userId;
    final syncCache = asSyncCacheForUser(
      ref.watch(asSyncCacheProvider),
      currentUserId,
    );
    final hiddenConversationIds = ref.watch(homeHiddenConversationIdsProvider);
    final summaryState = ref.watch(conversationSummaryProvider);
    final pinnedConversationIds = ref.watch(pinnedConversationIdsProvider);
    final groupRemarkNames = ref.watch(groupRemarkNamesProvider);
    final outbox = ref.watch(localOutboxProvider);
    final messageOrder = ref.watch(localMessageOrderProvider);
    final productConversationsAsync = ref.watch(productConversationsProvider);
    final productConversations =
        productConversationsAsync.valueOrNull ?? const <AsConversation>[];
    final productConversationsByRoomId = {
      for (final conversation in productConversations)
        if (conversation.roomId.trim().isNotEmpty)
          conversation.roomId.trim(): conversation,
    };
    final asRoomSummariesByRoomId = <String, AsSyncRoomSummary>{
      for (final room in syncCache.bootstrap?.rooms ?? const [])
        if (room.roomId.trim().isNotEmpty) room.roomId.trim(): room,
    };

    if (isAuthLoading) {
      return const _Empty(
        icon: Symbols.sync,
        title: '正在同步消息',
        subtitle: '请稍候',
      );
    }

    final visibleConversations = <_VisibleConversation>[];
    final visibleRoomIds = <String>{};
    void addVisibleConversation(_VisibleConversation conversation) {
      final roomId = conversation.roomId.trim();
      if (roomId.isEmpty || !visibleRoomIds.add(roomId)) return;
      visibleConversations.add(conversation);
    }

    final agentMxid = portalAgentMxidForClient(client);
    final canonicalAgentRoomId = syncCache.bootstrap?.agentRoomId.trim() ?? '';
    var fallbackAgentShown = false;
    for (final room in rooms) {
      if (room.membership != Membership.join) continue;
      if (_isAgentRoom(room, agentMxid)) {
        if (canonicalAgentRoomId.isNotEmpty) {
          if (room.id != canonicalAgentRoomId) continue;
        } else {
          if (fallbackAgentShown) continue;
          fallbackAgentShown = true;
        }
        addVisibleConversation(_VisibleConversation.agent(room));
      }
    }
    for (final conversation in productConversations) {
      if (conversation.isChannel) continue;
      if (!conversation.canOpen) continue;
      final roomId = conversation.roomId.trim();
      addVisibleConversation(
        _VisibleConversation.product(
          conversation,
          client.getRoomById(roomId),
          asRoomSummariesByRoomId[roomId],
        ),
      );
    }

    final sortedConversations = [...visibleConversations]..sort((a, b) {
        final aPinned = pinnedConversationIds.contains(a.roomId);
        final bPinned = pinnedConversationIds.contains(b.roomId);
        if (aPinned != bPinned) return aPinned ? -1 : 1;
        if (a.isAgent != b.isAgent) return a.isAgent ? -1 : 1;
        return _conversationSortTime(
          b,
          outbox: outbox,
          messageOrder: messageOrder,
        ).compareTo(
          _conversationSortTime(
            a,
            outbox: outbox,
            messageOrder: messageOrder,
          ),
        );
      });
    final filteredConversations = [
      for (final conversation in sortedConversations)
        if (!hiddenConversationIds.contains(conversation.roomId)) conversation,
    ];
    final renderedConversations = [
      for (final conversation in filteredConversations)
        _renderHomeConversation(
          client: client,
          syncCache: syncCache,
          outbox: outbox,
          messageOrder: messageOrder,
          groupRemarkNames: groupRemarkNames,
          conversation: conversation,
        ),
    ];
    final cacheReady = summaryState.loaded;
    final cachedConversations = conversationSummaryEntriesForUser(
      summaryState.toSnapshot(),
      userId: currentUserId,
      hiddenConversationIds: hiddenConversationIds,
      pinnedConversationIds: pinnedConversationIds,
    );
    final liveSummaryEntries = [
      for (final rendered in renderedConversations)
        _summaryEntryFromRenderedConversation(rendered),
    ];
    final projectedConversations = mergeConversationSummaryEntries(
      cachedEntries:
          cacheReady ? cachedConversations : const <ConversationSummaryEntry>[],
      liveEntries: liveSummaryEntries,
      includeCachedOnlyEntries: !productConversationsAsync.hasValue,
      pinnedConversationIds: pinnedConversationIds,
    );
    if (cacheReady && projectedConversations.isNotEmpty) {
      _writeConversationSummaryEntries(
        ref,
        userId: currentUserId,
        entries: projectedConversations,
      );
    }
    final displayConversations = cachedConversations;

    if (displayConversations.isEmpty) {
      if (productConversationsAsync.isLoading && productConversations.isEmpty) {
        return const _Empty(
          icon: Symbols.sync,
          title: '正在同步消息',
          subtitle: '请稍候',
        );
      }
      if (!cacheReady && syncCache.bootstrap == null) {
        return const _Empty(
          icon: Symbols.sync,
          title: '正在读取本地消息',
          subtitle: '请稍候',
        );
      }
      return const _Empty(
        icon: Symbols.chat_bubble,
        title: '还没有会话',
        subtitle: '新的聊天会显示在这里',
      );
    }

    return _HomeConversationEntryList(
      entries: displayConversations,
      pinnedConversationIds: pinnedConversationIds,
      productConversationsByRoomId: productConversationsByRoomId,
    );
  }
}

class _HomeConversationEntryList extends ConsumerWidget {
  const _HomeConversationEntryList({
    required this.entries,
    required this.pinnedConversationIds,
    required this.productConversationsByRoomId,
  });

  final List<ConversationSummaryEntry> entries;
  final Set<String> pinnedConversationIds;
  final Map<String, AsConversation> productConversationsByRoomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 96),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final entry = entries[i];
        final roomId = entry.roomId.trim();
        final name = entry.name.trim().isEmpty ? roomId : entry.name.trim();
        final productConversation = productConversationsByRoomId[roomId];
        return _ConvRow(
          key: ValueKey('home_conversation_$roomId'),
          name: name,
          lastMessage: entry.lastMessage,
          time: entry.previewTs <= 0 ? '' : _formatConvTime(entry.previewTs),
          unread: entry.unread,
          isAgent: entry.isAgent,
          isGroup: entry.isGroup,
          avatarUrl: entry.avatarUrl.trim().isEmpty ? null : entry.avatarUrl,
          isPinned: pinnedConversationIds.contains(roomId),
          onTap: () {
            final route = productConversation == null
                ? null
                : productConversationRoute(productConversation);
            if (route != null) context.push(route);
          },
          onTogglePin: () => _toggleHomeConversationPin(ref, roomId),
          onHide: () => hideHomeConversation(ref, roomId),
          onDelete: () => _deleteHomeConversation(context, ref, roomId, name),
        );
      },
    );
  }
}

class _RenderedHomeConversation {
  const _RenderedHomeConversation({
    required this.conversation,
    required this.name,
    required this.lastMessage,
    required this.previewTime,
    required this.unread,
    required this.avatarUrl,
  });

  final _VisibleConversation conversation;
  final String name;
  final String lastMessage;
  final DateTime? previewTime;
  final int unread;
  final String? avatarUrl;
}

_RenderedHomeConversation _renderHomeConversation({
  required Client client,
  required AsSyncCacheState syncCache,
  required LocalOutboxState outbox,
  required LocalMessageOrderState messageOrder,
  required Map<String, String> groupRemarkNames,
  required _VisibleConversation conversation,
}) {
  final room = conversation.room;
  final lastEvent = room?.lastEvent;
  final visibilityPolicy = syncCache.chatVisibilityPolicyForRoom(
    conversation.roomId,
  );
  final visibleLastEvent = lastEvent != null &&
          visibilityPolicy.allows(
            eventId: lastEvent.eventId,
            originServerTs: lastEvent.originServerTs.millisecondsSinceEpoch,
            redacted: lastEvent.redacted,
          )
      ? lastEvent
      : null;
  final failedOutbox = _latestFailedMediaOutboxForConversation(
    outbox,
    conversation,
  );
  final lastEventSortTime = visibleLastEvent == null
      ? null
      : messageOrder.entryForEvent(visibleLastEvent.eventId)?.createdAt;
  final cleared = visibilityPolicy.clearedBeforeTs > 0 &&
      visibleLastEvent == null &&
      failedOutbox == null;
  final previewTime = _conversationPreviewTimeForConversation(
    conversation,
    lastEvent: visibleLastEvent,
    latestFailedOutbox: failedOutbox,
    lastEventSortTime: lastEventSortTime,
    cleared: cleared,
  );
  final lastMessage = _conversationPreviewTextForConversation(
    conversation,
    lastEvent: visibleLastEvent,
    latestFailedOutbox: failedOutbox,
    lastEventSortTime: lastEventSortTime,
    cleared: cleared,
  );
  final displayName = conversation.isAgent
      ? 'Agent'
      : _conversationDisplayName(
          conversation,
          groupRemarkNames: groupRemarkNames,
        );
  return _RenderedHomeConversation(
    conversation: conversation,
    name: displayName,
    lastMessage: lastMessage,
    previewTime: previewTime,
    unread: _conversationUnreadCount(conversation, room, syncCache),
    avatarUrl: _conversationAvatarUrl(client, conversation, room),
  );
}

ConversationSummaryEntry _summaryEntryFromRenderedConversation(
  _RenderedHomeConversation rendered,
) {
  final roomId = rendered.conversation.roomId.trim();
  final product = rendered.conversation.product;
  return ConversationSummaryEntry(
    conversationId: product?.conversationId ?? '',
    roomId: roomId,
    kind: product?.kind ?? '',
    name: rendered.name,
    lastMessage: rendered.lastMessage,
    previewTs: rendered.previewTime?.millisecondsSinceEpoch ?? 0,
    unread:
        _renderedConversationHasUnreadSignal(rendered) ? rendered.unread : 0,
    isGroup: rendered.conversation.isGroup,
    isAgent: rendered.conversation.isAgent,
    canOpen: product?.canOpen ?? true,
    avatarUrl: rendered.avatarUrl ?? '',
  );
}

bool _renderedConversationHasUnreadSignal(_RenderedHomeConversation rendered) {
  final conversation = rendered.conversation;
  return rendered.unread > 0 ||
      conversation.room != null ||
      conversation.product != null ||
      conversation.roomSummary != null;
}

void _writeConversationSummaryEntries(
  WidgetRef ref, {
  required String? userId,
  required List<ConversationSummaryEntry> entries,
}) {
  unawaited(
    Future.microtask(
      () => ref.read(conversationSummaryProvider.notifier).replaceForUser(
            userId: userId,
            entries: entries,
          ),
    ),
  );
}

Future<void> _deleteHomeConversation(
  BuildContext context,
  WidgetRef ref,
  String roomId,
  String name,
) async {
  final trimmed = roomId.trim();
  if (trimmed.isEmpty) return;
  final authNotifier = ref.read(authStateNotifierProvider.notifier);
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final t = dialogContext.tk;
      return AlertDialog(
        title: Text(
          '删除聊天记录',
          style: AppTheme.sans(size: 17, weight: FontWeight.w600),
        ),
        content: Text(
          '确定删除「$name」的所有聊天记录？该操作不可恢复。',
          style: AppTheme.sans(size: 15, color: t.textMute),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              '取消',
              style: AppTheme.sans(size: 15, color: t.textMute),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              '删除',
              style: AppTheme.sans(
                size: 15,
                weight: FontWeight.w600,
                color: t.danger,
              ),
            ),
          ),
        ],
      );
    },
  );
  if (ok != true) return;
  try {
    final clearedBeforeTs = DateTime.now().toUtc().millisecondsSinceEpoch + 1;
    await ref.read(matrixMessageVisibilityClientProvider).clearRoom(trimmed);
    hideHomeConversation(ref, trimmed);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已删除「$name」')),
      );
    }
    try {
      await authNotifier.clearRoomChatHistory(
        trimmed,
        clearedBeforeTs: clearedBeforeTs,
      );
    } catch (localError) {
      debugPrint('clear local room chat history failed: $localError');
    }
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('删除聊天记录失败: $error')),
    );
  }
}

void _toggleHomeConversationPin(WidgetRef ref, String roomId) {
  final trimmed = roomId.trim();
  if (trimmed.isEmpty) return;
  toggleConversationPin(ref, trimmed);
}

class _VisibleConversation {
  const _VisibleConversation._({
    required this.roomId,
    this.room,
    this.product,
    this.roomSummary,
    this.isAgent = false,
    this.isGroup = false,
  });

  factory _VisibleConversation.agent(Room room) {
    return _VisibleConversation._(roomId: room.id, room: room, isAgent: true);
  }

  factory _VisibleConversation.product(
    AsConversation conversation,
    Room? room, [
    AsSyncRoomSummary? roomSummary,
  ]) {
    return _VisibleConversation._(
      roomId: conversation.roomId.trim(),
      room: room,
      product: conversation,
      roomSummary: roomSummary,
      isAgent: conversation.isAgent,
      isGroup: conversation.isGroup,
    );
  }

  final String roomId;
  final Room? room;
  final AsConversation? product;
  final AsSyncRoomSummary? roomSummary;
  final bool isAgent;
  final bool isGroup;
}

String? _conversationAvatarUrl(
  Client client,
  _VisibleConversation conversation,
  Room? room,
) {
  if (conversation.isAgent) return null;
  final productAvatar = avatarHttpUrl(client, conversation.product?.avatarUrl);
  if (conversation.isGroup) {
    return productAvatar ?? (room == null ? null : roomAvatarHttpUrl(room));
  }

  return productAvatar ??
      _directPeerMemberAvatarUrl(
        client,
        room,
        conversation.product?.peerMxid,
      ) ??
      avatarHttpUrl(client, conversation.roomSummary?.avatarUrl) ??
      (room == null ? null : roomAvatarHttpUrl(room));
}

String? _contactListAvatarUrl(Client client, AsSyncContact contact) {
  final room = client.getRoomById(contact.roomId.trim());
  return _directPeerMemberAvatarUrl(client, room, contact.userId) ??
      avatarHttpUrl(client, contact.avatarUrl);
}

String? _directPeerMemberAvatarUrl(
  Client client,
  Room? room,
  String? peerUserId,
) {
  final peerId = peerUserId?.trim() ?? '';
  if (room == null || peerId.isEmpty) return null;
  final member = room.unsafeGetUserFromMemoryOrFallback(peerId);
  return matrixContentHttpUrl(client, member.avatarUrl);
}

LocalOutboxItem? _latestFailedMediaOutboxForConversation(
  LocalOutboxState outbox,
  _VisibleConversation conversation,
) {
  final type = conversation.isGroup
      ? LocalOutboxConversationType.group
      : conversation.isAgent
          ? LocalOutboxConversationType.agent
          : LocalOutboxConversationType.direct;
  final items = outbox
      .itemsForConversation(conversation.roomId, type: type)
      .where(
        (item) =>
            item.status == LocalOutboxItemStatus.failed &&
            (item.messageKind == LocalOutboxMessageKind.image ||
                item.messageKind == LocalOutboxMessageKind.video ||
                item.messageKind == LocalOutboxMessageKind.file),
      )
      .toList();
  if (items.isEmpty && type != LocalOutboxConversationType.direct) {
    items.addAll(
      outbox.itemsForConversation(conversation.roomId).where(
            (item) =>
                item.status == LocalOutboxItemStatus.failed &&
                (item.messageKind == LocalOutboxMessageKind.image ||
                    item.messageKind == LocalOutboxMessageKind.video ||
                    item.messageKind == LocalOutboxMessageKind.file),
          ),
    );
  }
  if (items.isEmpty) return null;
  items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return items.first;
}

String _conversationDisplayName(
  _VisibleConversation conversation, {
  Map<String, String> groupRemarkNames = const {},
}) {
  if (conversation.isGroup) {
    final remark = groupRemarkNames[conversation.roomId]?.trim() ?? '';
    if (remark.isNotEmpty) return remark;
  }
  final productTitle = conversation.product?.title.trim() ?? '';
  if (productTitle.isNotEmpty) return productTitle;
  if (!conversation.isAgent) {
    final peerName = _directProductPeerDisplayName(
      conversation.product,
      conversation.room,
    );
    if (peerName.isNotEmpty) return peerName;
  }
  return conversation.room?.getLocalizedDisplayname() ?? '';
}

String _directProductPeerDisplayName(AsConversation? product, Room? room) {
  final peerMxid = product?.peerMxid.trim() ?? '';
  if (peerMxid.isEmpty) return '';
  final memberName = directPeerMemberDisplayName(room, peerMxid);
  if (memberName.isEmpty || memberName == localpartFromMxid(peerMxid)) {
    return '';
  }
  return memberName;
}

String _conversationPreviewTextForConversation(
  _VisibleConversation conversation, {
  required Event? lastEvent,
  required LocalOutboxItem? latestFailedOutbox,
  DateTime? lastEventSortTime,
  bool cleared = false,
}) {
  if (cleared) return '';
  final text = conversationPreviewText(
    lastEvent: lastEvent,
    latestFailedOutbox: latestFailedOutbox,
    lastEventSortTime: lastEventSortTime,
    isAgent: conversation.isAgent,
  );
  if (text.isNotEmpty) return text;
  final productLastMessage = conversation.product?.lastMessage.trim() ?? '';
  if (productLastMessage.isNotEmpty) return productLastMessage;
  return '';
}

DateTime? _conversationPreviewTimeForConversation(
  _VisibleConversation conversation, {
  required Event? lastEvent,
  required LocalOutboxItem? latestFailedOutbox,
  DateTime? lastEventSortTime,
  bool cleared = false,
}) {
  if (cleared) return null;
  final previewTime = conversationPreviewTime(
    lastEvent: lastEvent,
    latestFailedOutbox: latestFailedOutbox,
    lastEventSortTime: lastEventSortTime,
  );
  if (previewTime != null) return previewTime;
  return conversation.product?.lastActivityAt ??
      conversation.roomSummary?.lastActivityAt;
}

bool _isAgentRoom(Room room, String? agentMxid) {
  return isPortalAgentDirectRoom(room, agentMxid: agentMxid);
}

int _conversationUnreadCount(
  _VisibleConversation conversation,
  Room? room,
  AsSyncCacheState syncCache,
) {
  final asRoomUnread = conversation.roomSummary?.unreadCount ?? 0;
  if (asRoomUnread > 0) return asRoomUnread;

  final matrixUnread = conversationUnreadCount(
    matrixUnreadCount: room?.notificationCount ?? 0,
  );
  if (matrixUnread > 0) return matrixUnread;

  return 0;
}

bool _hasUnclassifiedJoinedRooms({
  required Client client,
  required AsSyncCacheState syncCache,
  required String? agentMxid,
}) {
  final bootstrap = syncCache.bootstrap;
  if (bootstrap == null) {
    return client.rooms.any((room) {
      return room.membership == Membership.join &&
          !_isAgentRoom(room, agentMxid);
    });
  }
  final knownRoomIds = <String>{
    if (bootstrap.agentRoomId.trim().isNotEmpty) bootstrap.agentRoomId.trim(),
    for (final contact in bootstrap.contacts)
      if (contact.roomId.trim().isNotEmpty) contact.roomId.trim(),
    for (final group in bootstrap.groups)
      if (group.roomId.trim().isNotEmpty) group.roomId.trim(),
    for (final channel in bootstrap.channels)
      if (channel.roomId.trim().isNotEmpty) channel.roomId.trim(),
  };
  return client.rooms.any((room) {
    if (room.membership != Membership.join) return false;
    if (_isAgentRoom(room, agentMxid)) return false;
    return !knownRoomIds.contains(room.id.trim());
  });
}

bool _hasPendingInviteRooms({
  required Client client,
  required String? agentMxid,
}) {
  return client.rooms.any((room) {
    if (room.membership != Membership.invite) return false;
    return !_isAgentRoom(room, agentMxid);
  });
}

int _conversationSortTime(
  _VisibleConversation conversation, {
  required LocalOutboxState outbox,
  required LocalMessageOrderState messageOrder,
}) {
  final lastEvent = conversation.room?.lastEvent;
  final failedOutbox =
      _latestFailedMediaOutboxForConversation(outbox, conversation);
  final lastEventSortTime = lastEvent == null
      ? null
      : messageOrder.entryForEvent(lastEvent.eventId)?.createdAt;
  return _conversationPreviewTimeForConversation(
        conversation,
        lastEvent: lastEvent,
        latestFailedOutbox: failedOutbox,
        lastEventSortTime: lastEventSortTime,
      )?.millisecondsSinceEpoch ??
      0;
}

String _formatConvTime(int ts) {
  final dt = DateTime.fromMillisecondsSinceEpoch(ts);
  final now = DateTime.now();
  if (now.difference(dt).inDays == 0) return DateFormat('HH:mm').format(dt);
  if (now.difference(dt).inDays == 1) return '昨天';
  if (now.difference(dt).inDays < 7) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekdays[dt.weekday - 1];
  }
  return DateFormat('MM/dd').format(dt);
}

/// 会话列表行 —— 对齐 Figma node 53:505。
/// 头像 42×42、圆角 8、头像与内容间距 8，右侧时间/未读固定宽度。
class _ConvRow extends StatelessWidget {
  const _ConvRow({
    super.key,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unread,
    required this.onTap,
    required this.onTogglePin,
    required this.onHide,
    required this.onDelete,
    this.isAgent = false,
    this.isGroup = false,
    this.isPinned = false,
    this.avatarUrl,
  });
  final String name;
  final String lastMessage;
  final String time;
  final int unread;
  final VoidCallback? onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onHide;
  final VoidCallback onDelete;
  final bool isAgent;
  final bool isGroup;
  final bool isPinned;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    Offset rcPos = Offset.zero;
    final textColor = _homeTextColor(context);
    final mutedColor = _homeMutedColor(context);
    final borderColor = _homeBorderColor(context);
    final avatar = SizedBox(
      width: _conversationTileAvatarSize,
      height: _conversationTileAvatarSize,
      child: isAgent
          ? Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE8F3FF),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Symbols.robot_2,
                size: 22,
                color: Color(0xFF0066A8),
                fill: 1,
              ),
            )
          : isGroup
              ? _GroupAvatarGrid(seed: name, imageUrl: avatarUrl)
              : PortalAvatar(
                  seed: name,
                  size: _conversationTileAvatarSize,
                  imageUrl: avatarUrl,
                  shape: AvatarShape.squircle,
                ),
    );

    return GestureDetector(
      onSecondaryTapDown: (d) => rcPos = d.globalPosition,
      onSecondaryTap: () => _showChatCtxMenu(
        context,
        rcPos,
        name,
        isPinned: isPinned,
        onTogglePin: onTogglePin,
        onHide: onHide,
        onDelete: onDelete,
      ),
      onLongPressStart: (d) {
        rcPos = d.globalPosition;
        _showChatCtxMenu(
          context,
          rcPos,
          name,
          isPinned: isPinned,
          onTogglePin: onTogglePin,
          onHide: onHide,
          onDelete: onDelete,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                avatar,
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: borderColor, width: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTheme.sans(
                                          size: 14,
                                          weight: FontWeight.w600,
                                          color: textColor,
                                        ),
                                      ),
                                    ),
                                    if (isAgent) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        Symbols.smart_toy,
                                        size: 14,
                                        color: mutedColor,
                                      ),
                                    ],
                                    if (isPinned) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        Symbols.push_pin,
                                        size: 14,
                                        color: mutedColor,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTheme.sans(
                                    size: 12,
                                    color: mutedColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 36,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (time.isNotEmpty)
                                Text(
                                  time,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: AppTheme.sans(
                                    size: 12,
                                    weight: FontWeight.w500,
                                    color: mutedColor,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              if (unread > 0)
                                _ConversationUnreadBadge(count: unread)
                              else
                                const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationUnreadBadge extends StatelessWidget {
  const _ConversationUnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = _formatBadgeCount(count);
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFFF5656),
        shape: BoxShape.circle,
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        textHeightBehavior: const TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
        ),
        style: AppTheme.sans(
          size: label.length > 2 ? 8 : 11,
          weight: FontWeight.w700,
          color: Colors.white,
        ).copyWith(height: 1),
      ),
    );
  }
}

void _showChatCtxMenu(
  BuildContext context,
  Offset pos,
  String name, {
  required bool isPinned,
  required VoidCallback onTogglePin,
  required VoidCallback onHide,
  required VoidCallback onDelete,
}) {
  final size = MediaQuery.of(context).size;
  const menuW = 176.0;
  const menuH = 148.0;
  var left = pos.dx;
  var top = pos.dy;
  if (left + menuW > size.width - 8) left = size.width - menuW - 8;
  if (top + menuH > size.height - 8) top = size.height - menuH - 8;
  if (left < 8) left = 8;
  if (top < 8) top = 8;

  showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'chat-ctx',
    barrierColor: Colors.black.withValues(alpha: 0.15),
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (ctx, _, __) => Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: menuW,
          child: _ChatCtxMenuCard(
            name: name,
            isPinned: isPinned,
            onTogglePin: onTogglePin,
            onHide: onHide,
            onDelete: onDelete,
          ),
        ),
      ],
    ),
    transitionBuilder: (ctx, a, _, child) =>
        FadeTransition(opacity: a, child: child),
  );
}

class _ChatCtxMenuCard extends StatelessWidget {
  const _ChatCtxMenuCard({
    required this.name,
    required this.isPinned,
    required this.onTogglePin,
    required this.onHide,
    required this.onDelete,
  });
  final String name;
  final bool isPinned;
  final VoidCallback onTogglePin;
  final VoidCallback onHide;
  final VoidCallback onDelete;

  // chat-ctx-menu 用固定深色，与 light/dark 主题无关（对齐 index.html#chat-ctx-menu）。
  static const _dark = Color(0xFF1E2026);
  static const _divider = Color(0x1AFFFFFF);
  static const _icon = Color(0xB3FFFFFF);
  static const _label = Colors.white;
  static const _danger = Color(0xFFFF6B6B);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: _dark,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _row(context, isPinned ? Symbols.keep_off : Symbols.push_pin,
                isPinned ? '取消置顶' : '置顶', () {
              Navigator.of(context).pop();
              onTogglePin();
              _toast(context, isPinned ? '已取消置顶「$name」' : '已置顶「$name」');
            }),
            const Divider(
              height: 1,
              color: _divider,
              indent: 16,
              endIndent: 16,
            ),
            _row(context, Symbols.visibility_off, '不显示', () {
              Navigator.of(context).pop();
              onHide();
              _toast(context, '已隐藏「$name」');
            }),
            const Divider(
              height: 1,
              color: _divider,
              indent: 16,
              endIndent: 16,
            ),
            _row(context, Symbols.delete, '删除聊天', () {
              Navigator.of(context).pop();
              onDelete();
            }, danger: true),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext ctx,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool danger = false,
  }) {
    final color = danger ? _danger : _label;
    final iconColor = danger ? _danger : _icon;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 12),
            Text(label, style: AppTheme.sans(size: 15, color: color)),
          ],
        ),
      ),
    );
  }

  void _toast(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );
  }
}

class _ContactList extends ConsumerWidget {
  const _ContactList({required this.client});
  final Client client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncCache = ref.watch(asSyncCacheProvider);
    final friendRequestReadState = ref.watch(friendRequestReadProvider);
    final acceptedContacts = syncCache.acceptedContacts;
    final pendingInvites = friendRequestReadState.unreadCountForRoomIds(
      _pendingFriendRequestRoomIds(client: client, syncCache: syncCache),
    );
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final contacts = acceptedContacts.map((contact) {
      final peerMxid = contact.userId.trim();
      final room = client.getRoomById(contact.roomId.trim());
      final contactName = contact.displayName.trim();
      final memberName = directPeerMemberDisplayName(room, peerMxid);
      return _ContactListEntry(
        name: contactDisplayNameFromIdentity(
          mxid: peerMxid,
          displayName: contactName.isNotEmpty ? contactName : memberName,
          domain: contact.domain,
        ),
        mxid: peerMxid,
        avatarUrl: _contactListAvatarUrl(client, contact),
      );
    }).toList();
    final groupedContacts = _groupContactsByInitial(contacts);
    final sectionKeys = groupedContacts.keys.toList()
      ..sort((a, b) {
        if (a == '#') return 1;
        if (b == '#') return -1;
        return a.compareTo(b);
      });

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 96),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: HomeSearchBox(
                hint: l10n?.contactsSearchHint ?? 'ID/昵称/邮箱',
                onTap: () => context.push('/search'),
              ),
            ),
            const SizedBox(height: 8),
            _ActionSection(
              emptyFallback: const SizedBox.shrink(),
              children: [
                _SectionAction(
                  iconAsset: _iconMenuAddFriend,
                  label: l10n?.contactsNewFriends ?? '新朋友',
                  badgeKeyLabel: '新朋友',
                  badge: pendingInvites > 0
                      ? _formatBadgeCount(pendingInvites)
                      : null,
                  onTap: () => context.push('/requests'),
                ),
                _SectionAction(
                  iconAsset: _iconTabContacts,
                  label: l10n?.contactsMyGroups ?? '我的群组',
                  onTap: () => context.push('/groups'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (contacts.isEmpty)
              const _Empty(
                icon: Symbols.person,
                title: '还没有联系人',
                subtitle: '添加联系人后会显示在这里',
              )
            else
              for (final sectionKey in sectionKeys) ...[
                _ContactSectionHeader(label: sectionKey),
                _ActionSection(
                  emptyFallback: const SizedBox.shrink(),
                  children: groupedContacts[sectionKey]!
                      .map(
                        (contact) => _ContactEntryTile(
                          name: contact.name,
                          avatarUrl: contact.avatarUrl,
                          onTap: () {
                            if (contact.mxid.isNotEmpty) {
                              context.push(
                                '/contact/${Uri.encodeComponent(contact.mxid)}',
                              );
                            }
                          },
                        ),
                      )
                      .toList(),
                ),
              ],
          ],
        ),
        if (contacts.isNotEmpty)
          Positioned(
            top: 210,
            right: 8,
            bottom: 110,
            child: _AlphabetIndex(activeLetters: sectionKeys.toSet()),
          ),
      ],
    );
  }
}

class _ContactListEntry {
  const _ContactListEntry({
    required this.name,
    required this.mxid,
    this.avatarUrl,
  });

  final String name;
  final String mxid;
  final String? avatarUrl;
}

Map<String, List<_ContactListEntry>> _groupContactsByInitial(
  List<_ContactListEntry> contacts,
) {
  final grouped = <String, List<_ContactListEntry>>{};
  final sorted = [...contacts]
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  for (final contact in sorted) {
    final key = _contactInitial(contact.name);
    grouped.putIfAbsent(key, () => []).add(contact);
  }
  return grouped;
}

String _contactInitial(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '#';
  final first = trimmed.characters.first.toUpperCase();
  final code = first.codeUnitAt(0);
  return code >= 65 && code <= 90 ? first : '#';
}

class HomeSearchBox extends StatelessWidget {
  const HomeSearchBox({super.key, required this.hint, required this.onTap});
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return M3SearchField(
      hint: hint,
      readOnly: true,
      onTap: onTap,
    );
  }
}

class _ActionSection extends StatelessWidget {
  const _ActionSection({
    required this.children,
    this.emptyFallback = const _Empty(
      icon: Symbols.person,
      title: '还没有联系人',
      subtitle: '添加联系人后会显示在这里',
    ),
  });

  final List<Widget> children;
  final Widget emptyFallback;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return emptyFallback;
    }
    return Column(children: children);
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: t.textMute),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTheme.sans(
                size: 15,
                weight: FontWeight.w600,
                color: t.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTheme.sans(size: 12, color: t.textMute),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactSectionHeader extends StatelessWidget {
  const _ContactSectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: AppTheme.sans(
              size: 16,
              weight: FontWeight.w600,
              color: _homeTextColor(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _AlphabetIndex extends StatelessWidget {
  const _AlphabetIndex({required this.activeLetters});

  static const _letters = [
    '#',
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
  ];

  final Set<String> activeLetters;

  @override
  Widget build(BuildContext context) {
    final muted = _homeMutedColor(context);
    final active = _homeTextColor(context);
    return IgnorePointer(
      child: SizedBox(
        width: 12,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _letters
                .map(
                  (letter) => Text(
                    letter,
                    style: AppTheme.sans(
                      size: 10,
                      weight: activeLetters.contains(letter)
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: activeLetters.contains(letter) ? active : muted,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _SectionAction extends StatelessWidget {
  const _SectionAction({
    required this.iconAsset,
    required this.label,
    required this.onTap,
    this.badgeKeyLabel,
    this.badge,
  });

  final String iconAsset;
  final String label;
  final VoidCallback onTap;
  final String? badgeKeyLabel;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return _ContactFlatRow(
      onTap: onTap,
      leading: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: t.primaryContainer,
          borderRadius: BorderRadius.circular(5),
        ),
        alignment: Alignment.center,
        child: _DesignAssetIcon(
          assetName: iconAsset,
          size: 18,
          color: t.onPrimaryContainer,
        ),
      ),
      title: label,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge != null) ...[
            Container(
              key: ValueKey('section_action_badge_${badgeKeyLabel ?? label}'),
              height: 20,
              constraints: const BoxConstraints(minWidth: 20),
              padding: EdgeInsets.symmetric(
                horizontal: badge!.length > 2 ? 5 : 0,
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFFF5656),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge!,
                textAlign: TextAlign.center,
                style: AppTheme.sans(
                  size: badge!.length > 2 ? 9 : 11,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ).copyWith(height: 1),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactFlatRow extends StatelessWidget {
  const _ContactFlatRow({
    required this.leading,
    required this.title,
    required this.onTap,
    this.trailing,
  });

  final Widget leading;
  final String title;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = _homeTextColor(context);
    final borderColor = _homeBorderColor(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: borderColor, width: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.sans(
                                size: 14,
                                weight: FontWeight.w500,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(width: 8),
                        trailing!,
                      ],
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

class _ContactEntryTile extends StatelessWidget {
  const _ContactEntryTile({
    required this.name,
    required this.onTap,
    this.avatarUrl,
  });

  final String name;
  final VoidCallback onTap;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return _ContactFlatRow(
      onTap: onTap,
      leading: SizedBox(
        width: 28,
        height: 28,
        child: PortalAvatar(
          seed: name,
          size: 28,
          imageUrl: avatarUrl,
          shape: AvatarShape.squircle,
        ),
      ),
      title: name,
    );
  }
}

class _DetailPlaceholder extends StatelessWidget {
  const _DetailPlaceholder({required this.tabTitle});

  final String tabTitle;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      color: t.bg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.forum, size: 48, color: t.textMute),
            const SizedBox(height: 14),
            Text(
              '选择左侧的$tabTitle查看详情',
              style: AppTheme.sans(size: 14, color: t.textMute),
            ),
            const SizedBox(height: 6),
            Text(
              tabTitle == '消息' ? 'Agent 会像普通联系人一样出现在消息列表中' : '详情区域会在这里展开',
              style: AppTheme.sans(size: 12, color: t.textMute),
            ),
          ],
        ),
      ),
    );
  }
}
