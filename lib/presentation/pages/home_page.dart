import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:intl/intl.dart';
import '../channel/channel_inbox_data.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_bootstrap_store_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/conversation_preferences_provider.dart';
import '../providers/friend_request_read_provider.dart';
import '../providers/local_message_order_provider.dart';
import '../providers/local_outbox_provider.dart';
import '../widgets/portal_avatar.dart';
import '../mock/mock_data.dart';
import '../../data/as_client.dart';
import '../../data/local_outbox_store.dart';
import '../../l10n/app_localizations.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../providers/app_warmup_provider.dart';
import '../providers/personal_space_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/voice_call_provider.dart';
import '../call/voice_call_controller.dart';
import '../call/voice_call_display_name.dart';
import '../utils/avatar_url.dart';
import '../utils/group_creation_flow.dart';
import '../utils/message_preview.dart';
import '../widgets/app_glass_background.dart';
import '../widgets/m3/glass_header.dart';
import '../widgets/m3/m3_search_field.dart';
import '../utils/contact_identity_label.dart';
import '../utils/direct_contact_status.dart';

const _mockAuthEnabled = bool.fromEnvironment(
  'P2P_MATRIX_MOCK_AUTH',
  defaultValue: false,
);
const _homeBg = Color(0xFFFAFAFA);
const _homeText = Color(0xFF262628);
const _homeMuted = Color(0xFFA3A3A4);
const _homeBorder = Color(0xFFE6E6E6);
const _conversationTileAvatarSize = 42.0;
const _iconMenuAddFriend = 'assets/icons/menu_add_friend.svg';
const _iconMenuCreateGroup = 'assets/icons/menu_create_group.svg';
const _iconMenuCreateChannel = 'assets/icons/menu_create_channel.svg';
const _iconMenuAddCircle = 'assets/icons/menu_add_circle.svg';
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
const _assetMeSettings =
    'assets/resources/icon_account_setting__icon_account_setting.png';
const _assetMeQr = 'assets/resources/qr_code__qr_code.png';
const _assetMeChannels = 'assets/icons/me_channel.svg';
const _assetMeFavorites =
    'assets/resources/ic_profile_favorites__ic_profile_favorites.png';
const _assetMeComments =
    'assets/resources/ic_profile_verification__ic_profile_verification.png';
const _meIconBlue = Color(0xFF3097CB);
const _bottomSearchTapSize = 56.0;
const _bottomSearchIconSize = 48.0;
const _asBootstrapRefreshExistingMinInterval = Duration(seconds: 8);

final _homeHiddenConversationIdsProvider = StateProvider<Set<String>>(
  (ref) => const <String>{},
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
  bool _staleBootstrapClearScheduled = false;
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
      if (!mounted) return;
      final nextSignature = _homeSyncSignature(client);
      if (nextSignature == _lastHomeSyncSignature) return;
      _lastHomeSyncSignature = nextSignature;
      _scheduleAsBootstrapRefreshIfNeeded(refreshExisting: true);
      setState(() {});
    });
    if (!_mockAuthEnabled) {
      unawaited(ref.read(appWarmupProvider.future));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncSub?.cancel();
    _voiceCallSub?.cancel();
    _groupCallSub?.cancel();
    _asBootstrapRefreshTimer?.cancel();
    super.dispose();
  }

  void _attachVoiceCallController(Client client) {
    if (_mockAuthEnabled || !client.isLogged()) return;
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

  void _scheduleAsBootstrapRefreshIfNeeded({bool refreshExisting = false}) {
    if (_mockAuthEnabled || _asBootstrapRefreshInFlight) return;
    if (_asBootstrapRefreshTimer?.isActive ?? false) return;
    if (refreshExisting) {
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

    _asBootstrapRefreshTimer = Timer(
      refreshExisting ? const Duration(milliseconds: 300) : Duration.zero,
      () {
        if (!mounted || _asBootstrapRefreshInFlight) return;
        _asBootstrapRefreshInFlight = true;
        _lastAsBootstrapRefreshAt = DateTime.now();
        unawaited(_refreshAsBootstrap());
      },
    );
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
                  2 => const _ChannelExplorePage(),
                  _ => _MePage(client: client),
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
    final textColor = _homeTextColor(context);
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
                  size: 20,
                  weight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _GlassCircleButton(
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
    0 => l10n?.tabChats ?? 'Chats',
    1 => l10n?.tabContacts ?? '通讯录',
    2 => l10n?.tabChannels ?? '频道',
    3 => l10n?.tabMe ?? '我的',
    _ => '',
  };
}

int _homeUnreadTotal(Client client, AsSyncCacheState syncCache) {
  var total = 0;
  for (final room in client.rooms) {
    if (room.membership == Membership.join) {
      total += conversationUnreadCount(
        matrixUnreadCount: room.notificationCount,
      );
    }
  }
  for (final room
      in syncCache.bootstrap?.rooms ?? const <AsSyncRoomSummary>[]) {
    total += room.unreadCount;
  }
  return total;
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
      ].join(','),
    );
  }
  return parts.join('|');
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
    final textColor = _homeTextColor(context);
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
                  size: 20,
                  weight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _GlassCircleButton(
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
  if (syncCache.bootstrap == null) {
    return client.rooms
        .where((r) => isIncomingDirectContactInvite(r, agentMxid: agentMxid))
        .map((r) => r.id.trim())
        .where((roomId) => roomId.isNotEmpty)
        .toList();
  }
  return syncCache.pendingInboundContacts
      .map((contact) => contact.roomId.trim())
      .where((roomId) => roomId.isNotEmpty)
      .toList();
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
      _showCreateChannelDialog(context, ref);
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
            height: 165,
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
                    iconAsset: _iconMenuCreateChannel,
                    overlayAsset: _iconMenuAddCircle,
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
    this.overlayAsset,
  });

  final String iconAsset;
  final String label;
  final _PlusAction value;
  final String? overlayAsset;

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
              overlayAssetName: overlayAsset,
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
    this.overlayAssetName,
  });

  final String assetName;
  final double size;
  final Color? color;
  final String? overlayAssetName;

  @override
  Widget build(BuildContext context) {
    final icon = _assetIcon(assetName, size: size, color: color);
    if (overlayAssetName == null) return icon;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: icon),
          Positioned(
            top: -1,
            right: -1,
            child: _assetIcon(
              overlayAssetName!,
              size: size * 0.5,
            ),
          ),
        ],
      ),
    );
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
    final isLoggedIn = authState.valueOrNull?.isLoggedIn ?? false;
    final currentUserId = client.userID ?? authState.valueOrNull?.userId;
    final syncCache = asSyncCacheForUser(
      ref.watch(asSyncCacheProvider),
      currentUserId,
    );
    final friendRequestReadState = ref.watch(friendRequestReadProvider);
    final pendingFriendRequests = friendRequestReadState.unreadCountForRoomIds(
      _pendingFriendRequestRoomIds(client: client, syncCache: syncCache),
    );
    final hiddenConversationIds = ref.watch(_homeHiddenConversationIdsProvider);
    final pinnedConversationIds = ref.watch(pinnedConversationIdsProvider);
    final groupRemarkNames = ref.watch(groupRemarkNamesProvider);
    final outbox = ref.watch(localOutboxProvider);
    final messageOrder = ref.watch(localMessageOrderProvider);
    final asGroupRoomIds = (syncCache.bootstrap?.groups ?? const [])
        .map((group) => group.roomId.trim())
        .where((roomId) => roomId.isNotEmpty)
        .toSet();
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

    // 未登录时展示 mock 会话用于演示；已登录则始终走真数据，
    // rooms 为空也显示真实空态，不回退 mock。
    if (_mockAuthEnabled || !isLoggedIn) {
      final convs = MockData.conversations.where((conversation) {
        return !hiddenConversationIds.contains(conversation.id);
      }).toList()
        ..sort((a, b) {
          final aPinned = pinnedConversationIds.contains(a.id);
          final bPinned = pinnedConversationIds.contains(b.id);
          if (aPinned != bPinned) return aPinned ? -1 : 1;
          return 0;
        });
      return ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 96),
        itemCount: convs.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return _ChatShortcutRow(
              iconAsset: _iconMenuAddFriend,
              name: '新的好友',
              lastMessage: '查看好友请求',
              unread: pendingFriendRequests,
              onTap: () => context.push('/requests'),
            );
          }
          final conversationIndex = i - 1;
          final c = convs[conversationIndex];
          final last = c.lastMessage;
          final isAgent = c.id == 'mock_aibot';
          return _ConvRow(
            name: isAgent ? 'Agent' : c.name,
            lastMessage: previewText(last?.text ?? c.subtitle),
            time: last == null ? '' : DateFormat('HH:mm').format(last.time),
            unread: c.unread,
            isAgent: isAgent,
            isGroup: c.isGroup,
            avatarUrl: c.avatarUrl,
            isPinned: pinnedConversationIds.contains(c.id),
            onTap: () => context.push('/chat/${c.id}'),
            onTogglePin: () => _toggleHomeConversationPin(ref, c.id),
            onDelete: () => _hideHomeConversation(ref, c.id),
          );
        },
      );
    }

    final agentMxid = portalAgentMxidForClient(client);
    if (syncCache.bootstrap == null &&
        rooms.any((room) => _needsAsClassification(room, agentMxid))) {
      return const _Empty(
        icon: Symbols.sync,
        title: '正在同步联系人信息',
        subtitle: '请稍候',
      );
    }

    final visibleConversations = <_VisibleConversation>[];
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
        visibleConversations.add(_VisibleConversation.agent(room));
      }
    }
    for (final contact in syncCache.acceptedContacts) {
      final roomId = contact.roomId.trim();
      if (roomId.isEmpty) continue;
      visibleConversations.add(
        _VisibleConversation.contact(
          contact,
          client.getRoomById(roomId),
          asRoomSummariesByRoomId[roomId],
        ),
      );
    }
    for (final group in syncCache.bootstrap?.groups ?? const []) {
      final roomId = group.roomId.trim();
      if (roomId.isEmpty || !asGroupRoomIds.contains(roomId)) continue;
      visibleConversations.add(
        _VisibleConversation.group(group, client.getRoomById(roomId)),
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
    _debugPrintConversationList(
      client: client,
      auth: authState.valueOrNull,
      syncCache: syncCache,
      rooms: rooms,
      conversations: filteredConversations,
      outbox: outbox,
    );

    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 96),
      itemCount: filteredConversations.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return _ChatShortcutRow(
            iconAsset: _iconMenuAddFriend,
            name: '新的好友',
            lastMessage: pendingFriendRequests > 0 ? '有新的好友请求' : '查看好友请求',
            unread: pendingFriendRequests,
            onTap: () => context.push('/requests'),
          );
        }
        final conversation = filteredConversations[i - 1];
        final room = conversation.room;
        final lastEvent = room?.lastEvent;
        final failedOutbox =
            _latestFailedMediaOutboxForConversation(outbox, conversation);
        final lastEventSortTime = lastEvent == null
            ? null
            : messageOrder.entryForEvent(lastEvent.eventId)?.createdAt;
        final previewTime = _conversationPreviewTimeForConversation(
          conversation,
          lastEvent: lastEvent,
          latestFailedOutbox: failedOutbox,
          lastEventSortTime: lastEventSortTime,
        );
        final lastMessage = _conversationPreviewTextForConversation(
          conversation,
          lastEvent: lastEvent,
          latestFailedOutbox: failedOutbox,
          lastEventSortTime: lastEventSortTime,
        );
        return _ConvRow(
          name: conversation.isAgent
              ? 'Agent'
              : _conversationDisplayName(
                  conversation,
                  groupRemarkNames: groupRemarkNames,
                ),
          lastMessage: lastMessage,
          time: previewTime == null
              ? ''
              : _formatConvTime(previewTime.millisecondsSinceEpoch),
          unread: _conversationUnreadCount(conversation, room),
          isAgent: conversation.isAgent,
          isGroup: conversation.isGroup,
          avatarUrl: _conversationAvatarUrl(client, conversation, room),
          isPinned: pinnedConversationIds.contains(conversation.roomId),
          onTap: () => conversation.isGroup
              ? context
                  .push('/group/${Uri.encodeComponent(conversation.roomId)}')
              : context
                  .push('/chat/${Uri.encodeComponent(conversation.roomId)}'),
          onTogglePin: () => _toggleHomeConversationPin(
            ref,
            conversation.roomId,
          ),
          onDelete: () => _hideHomeConversation(ref, conversation.roomId),
        );
      },
    );
  }
}

void _hideHomeConversation(WidgetRef ref, String roomId) {
  final trimmed = roomId.trim();
  if (trimmed.isEmpty) return;
  unpinConversation(ref, trimmed);
  ref.read(_homeHiddenConversationIdsProvider.notifier).update(
        (ids) => {...ids, trimmed},
      );
}

void _toggleHomeConversationPin(WidgetRef ref, String roomId) {
  final trimmed = roomId.trim();
  if (trimmed.isEmpty) return;
  toggleConversationPin(ref, trimmed);
}

void _debugPrintConversationList({
  required Client client,
  required AuthState? auth,
  required AsSyncCacheState syncCache,
  required List<Room> rooms,
  required List<_VisibleConversation> conversations,
  required LocalOutboxState outbox,
}) {
  if (!kDebugMode) return;
  final bootstrap = syncCache.bootstrap;
  final roomLines = rooms.map((room) {
    final last = room.lastEvent;
    return {
      'room_id': room.id,
      'membership': room.membership.name,
      'name': room.getLocalizedDisplayname(),
      'last_event_id': last?.eventId,
      'last_event_type': last?.type,
      'last_sender': last?.senderId,
      'unread': room.notificationCount,
    };
  }).toList();
  final conversationLines = conversations.map((conversation) {
    final room = conversation.room;
    return {
      'kind': conversation.isAgent
          ? 'agent'
          : conversation.isGroup
              ? 'group'
              : 'direct',
      'room_id': conversation.roomId,
      'name': conversation.isAgent
          ? 'Agent'
          : _conversationDisplayName(conversation),
      'contact_user_id': conversation.contact?.userId,
      'contact_status': conversation.contact?.status,
      'group_name': conversation.group?.name,
      'has_matrix_room': room != null,
      'matrix_membership': room?.membership.name,
      'matrix_last_event_id': room?.lastEvent?.eventId,
    };
  }).toList();
  final bootstrapContacts = [
    for (final contact in bootstrap?.contacts ?? const <AsSyncContact>[])
      {
        'user_id': contact.userId,
        'room_id': contact.roomId,
        'status': contact.status,
        'display_name': contact.displayName,
      },
  ];
  final bootstrapGroups = [
    for (final group in bootstrap?.groups ?? const <AsSyncRoomSummary>[])
      {
        'room_id': group.roomId,
        'name': group.name,
        'unread': group.unreadCount,
      },
  ];
  final bootstrapChannels = [
    for (final channel in bootstrap?.channels ?? const <AsSyncRoomSummary>[])
      {
        'room_id': channel.roomId,
        'name': channel.name,
        'unread': channel.unreadCount,
      },
  ];

  debugPrint(
    '[home.conversations] auth_user=${auth?.userId} '
    'client_user=${client.userID} homeserver=${client.homeserver} '
    'rooms=${rooms.length} bootstrap_user=${bootstrap?.user.userId} '
    'contacts=${bootstrapContacts.length} groups=${bootstrapGroups.length} '
    'channels=${bootstrapChannels.length} outbox=${outbox.items.length} '
    'visible=${conversations.length}',
  );
  debugPrint('[home.conversations] matrix_rooms=$roomLines');
  debugPrint('[home.conversations] bootstrap_contacts=$bootstrapContacts');
  debugPrint('[home.conversations] bootstrap_groups=$bootstrapGroups');
  debugPrint('[home.conversations] bootstrap_channels=$bootstrapChannels');
  debugPrint('[home.conversations] visible_conversations=$conversationLines');
}

class _VisibleConversation {
  const _VisibleConversation._({
    required this.roomId,
    this.room,
    this.contact,
    this.group,
    this.roomSummary,
    this.isAgent = false,
    this.isGroup = false,
  });

  factory _VisibleConversation.agent(Room room) {
    return _VisibleConversation._(roomId: room.id, room: room, isAgent: true);
  }

  factory _VisibleConversation.contact(
    AsSyncContact contact,
    Room? room, [
    AsSyncRoomSummary? roomSummary,
  ]) {
    return _VisibleConversation._(
      roomId: contact.roomId.trim(),
      room: room,
      contact: contact,
      roomSummary: roomSummary,
    );
  }

  factory _VisibleConversation.group(AsSyncRoomSummary group, Room? room) {
    return _VisibleConversation._(
      roomId: group.roomId.trim(),
      room: room,
      group: group,
      isGroup: true,
    );
  }

  final String roomId;
  final Room? room;
  final AsSyncContact? contact;
  final AsSyncRoomSummary? group;
  final AsSyncRoomSummary? roomSummary;
  final bool isAgent;
  final bool isGroup;

  bool get isContact => contact != null && !isGroup && !isAgent;
}

String? _conversationAvatarUrl(
  Client client,
  _VisibleConversation conversation,
  Room? room,
) {
  if (conversation.isAgent) return null;
  if (conversation.isGroup) {
    return avatarHttpUrl(client, conversation.group?.avatarUrl) ??
        (room == null ? null : roomAvatarHttpUrl(room));
  }

  final contact = conversation.contact;
  return avatarHttpUrl(client, contact?.avatarUrl) ??
      avatarHttpUrl(client, conversation.roomSummary?.avatarUrl) ??
      _directPeerMemberAvatarUrl(client, room, contact?.userId) ??
      (room == null ? null : roomAvatarHttpUrl(room));
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
  final group = conversation.group;
  if (conversation.isGroup) {
    final remark = groupRemarkNames[conversation.roomId]?.trim() ?? '';
    if (remark.isNotEmpty) return remark;
  }
  if (group != null) {
    final name = group.name.trim();
    if (name.isNotEmpty) return name;
  }
  final contact = conversation.contact;
  if (contact != null) {
    final label = contactDisplayNameFromIdentity(
      mxid: contact.userId,
      displayName: contact.displayName,
      domain: contact.domain,
    );
    if (label.isNotEmpty) return label;
  }
  return conversation.room?.getLocalizedDisplayname() ?? '';
}

String _conversationPreviewTextForConversation(
  _VisibleConversation conversation, {
  required Event? lastEvent,
  required LocalOutboxItem? latestFailedOutbox,
  DateTime? lastEventSortTime,
}) {
  final text = conversationPreviewText(
    lastEvent: lastEvent,
    latestFailedOutbox: latestFailedOutbox,
    lastEventSortTime: lastEventSortTime,
    isAgent: conversation.isAgent,
  );
  if (text.isNotEmpty) return text;
  final topic = conversation.group?.topic.trim() ?? '';
  if (topic.isNotEmpty) return previewText(topic);
  return '';
}

DateTime? _conversationPreviewTimeForConversation(
  _VisibleConversation conversation, {
  required Event? lastEvent,
  required LocalOutboxItem? latestFailedOutbox,
  DateTime? lastEventSortTime,
}) {
  return conversationPreviewTime(
        lastEvent: lastEvent,
        latestFailedOutbox: latestFailedOutbox,
        lastEventSortTime: lastEventSortTime,
      ) ??
      conversation.roomSummary?.lastActivityAt ??
      conversation.group?.lastActivityAt;
}

String _localpartFromMxid(String mxid) {
  if (!mxid.startsWith('@') || !mxid.contains(':')) return mxid;
  return mxid.substring(1, mxid.indexOf(':'));
}

bool _isAgentRoom(Room room, String? agentMxid) {
  return isPortalAgentDirectRoom(room, agentMxid: agentMxid);
}

int _conversationUnreadCount(_VisibleConversation conversation, Room? room) {
  final groupUnread = conversation.group?.unreadCount ?? 0;
  if (conversation.isGroup && groupUnread > 0) return groupUnread;

  final asRoomUnread = conversation.roomSummary?.unreadCount ?? 0;
  if (asRoomUnread > 0) return asRoomUnread;

  return conversationUnreadCount(
      matrixUnreadCount: room?.notificationCount ?? 0);
}

bool _needsAsClassification(Room room, String? agentMxid) {
  if (room.membership != Membership.join) return false;
  if (_isAgentRoom(room, agentMxid)) return false;
  if (room.isDirectChat) return true;
  return isProductDirectContactRoom(room, agentMxid: agentMxid);
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

void _homeToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
  );
}

class _ChatShortcutRow extends StatelessWidget {
  const _ChatShortcutRow({
    required this.iconAsset,
    required this.name,
    required this.lastMessage,
    required this.onTap,
    this.unread = 0,
  });

  final String iconAsset;
  final String name;
  final String lastMessage;
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = _homeTextColor(context);
    final mutedColor = _homeMutedColor(context);
    final borderColor = _homeBorderColor(context);
    final t = context.tk;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: _conversationTileAvatarSize,
                height: _conversationTileAvatarSize,
                decoration: BoxDecoration(
                  color: t.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: _DesignAssetIcon(
                  assetName: iconAsset,
                  size: 22,
                  color: t.onPrimaryContainer,
                ),
              ),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.sans(
                                size: 14,
                                weight: FontWeight.w600,
                                color: textColor,
                              ),
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
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 36,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: unread > 0
                              ? _ConversationUnreadBadge(count: unread)
                              : const SizedBox(height: 20),
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
    );
  }
}

/// 会话列表行 —— 对齐 Figma node 53:505。
/// 头像 42×42、圆角 8、头像与内容间距 8，右侧时间/未读固定宽度。
class _ConvRow extends StatelessWidget {
  const _ConvRow({
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unread,
    required this.onTap,
    required this.onTogglePin,
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
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
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
    required this.onDelete,
  });
  final String name;
  final bool isPinned;
  final VoidCallback onTogglePin;
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
              onDelete();
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
              _toast(context, '已删除「$name」');
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

Future<void> _showCreateChannelDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final draft = await showGeneralDialog<_CreateChannelDraft>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'create-channel',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, animation, secondaryAnimation) {
      return const _CreateChannelSheet();
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );

  if (draft == null || !context.mounted) return;
  final name = draft.name.trim();
  if (name.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('频道名称不能为空')),
    );
    return;
  }

  try {
    await ref.read(asClientProvider).createChannel(
      name: name,
      avatarUrl: draft.avatarUrl,
      visibility: draft.isPublic
          ? asChannelVisibilityPublic
          : asChannelVisibilityPrivate,
      joinPolicy: draft.needsApproval
          ? asChannelJoinPolicyApproval
          : asChannelJoinPolicyOpen,
      tags: [draft.type],
    );
    final bootstrap = await ref.read(asBootstrapRepositoryProvider).refresh();
    ref.read(asSyncCacheProvider.notifier).update(
          (state) => state.copyWith(bootstrap: bootstrap),
        );
    if (context.mounted) _homeToast(context, '频道已创建');
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('创建频道失败：$e')),
    );
  }
}

class _CreateChannelDraft {
  const _CreateChannelDraft({
    required this.name,
    required this.type,
    this.avatarUrl = '',
    required this.isPublic,
    required this.needsApproval,
  });

  final String name;
  final String type;
  final String avatarUrl;
  final bool isPublic;
  final bool needsApproval;
}

class _CreateChannelSheet extends ConsumerStatefulWidget {
  const _CreateChannelSheet();

  @override
  ConsumerState<_CreateChannelSheet> createState() =>
      _CreateChannelSheetState();
}

class _CreateChannelSheetState extends ConsumerState<_CreateChannelSheet> {
  final _nameCtrl = TextEditingController();
  String _type = '文字';
  String _avatarUrl = '';
  Uint8List? _avatarPreviewBytes;
  bool _avatarUploading = false;
  bool _isPublic = true;
  bool _needsApproval = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    if (_avatarUploading) return;
    setState(() => _avatarUploading = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1024,
        maxHeight: 1024,
        requestFullMetadata: false,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw StateError('empty channel avatar bytes');
      }
      if (mounted) {
        setState(() => _avatarPreviewBytes = bytes);
      }
      final uploaded = await ref.read(matrixClientProvider).uploadContent(
            bytes,
            filename:
                file.name.trim().isEmpty ? 'channel-avatar.jpg' : file.name,
            contentType: file.mimeType ?? _imageMimeTypeForName(file.name),
          );
      if (!mounted) return;
      setState(() => _avatarUrl = uploaded.toString());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('频道头像上传失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final t = context.tk;
    return Scaffold(
      backgroundColor: t.bg,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: GlassHeader.detail(
              title: '创建频道',
              onBack: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned.fill(
            top: topInset + 78,
            bottom: 96,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 38),
              children: [
                _CreateChannelCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _CreateChannelSectionHeader(
                        title: '频道名称',
                        meta: '必填',
                      ),
                      const SizedBox(height: 14),
                      _CreateChannelNameField(controller: _nameCtrl),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _CreateChannelCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _CreateChannelSectionHeader(
                        title: '上传频道头像',
                        meta: '可选',
                      ),
                      const SizedBox(height: 16),
                      _CreateChannelAvatarPicker(
                        previewBytes: _avatarPreviewBytes,
                        uploading: _avatarUploading,
                        onTap: _pickAvatar,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _CreateChannelCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _CreateChannelSectionHeader(
                        title: '选择频道类型',
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _CreateChannelTypeTile(
                              selected: _type == '文字',
                              icon: Symbols.chat_bubble,
                              title: '文字',
                              subtitle: '成员自由发言',
                              onTap: () => setState(() => _type = '文字'),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: _CreateChannelTypeTile(
                              selected: _type == '帖子',
                              icon: Symbols.article,
                              title: '帖子',
                              subtitle: '帖子与评论',
                              onTap: () => setState(() => _type = '帖子'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _CreateChannelCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '频道权限',
                        style: AppTheme.sans(
                          size: 16,
                          weight: FontWeight.w700,
                          color: t.text,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _CreateChannelSwitchRow(
                        title: '是否公开',
                        subtitle: '关闭后仅通过邀请加入',
                        value: _isPublic,
                        onChanged: (value) => setState(() => _isPublic = value),
                      ),
                      Divider(height: 24, color: t.border),
                      _CreateChannelSwitchRow(
                        title: '加入是否需要审核',
                        subtitle: '开启后需管理员通过',
                        value: _needsApproval,
                        onChanged: (value) =>
                            setState(() => _needsApproval = value),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 20,
            child: SafeArea(
              top: false,
              child: _CreateChannelSubmitButton(
                onTap: () {
                  if (_avatarUploading) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('频道头像上传中，请稍候')),
                    );
                    return;
                  }
                  Navigator.of(context).pop(
                    _CreateChannelDraft(
                      name: _nameCtrl.text,
                      type: _type,
                      avatarUrl: _avatarUrl,
                      isPublic: _isPublic,
                      needsApproval: _needsApproval,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateChannelCard extends StatelessWidget {
  const _CreateChannelCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: t.text.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CreateChannelSectionHeader extends StatelessWidget {
  const _CreateChannelSectionHeader({
    required this.title,
    this.meta,
  });

  final String title;
  final String? meta;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTheme.sans(
              size: 16,
              weight: FontWeight.w700,
              color: t.text,
            ),
          ),
        ),
        if (meta != null && meta!.trim().isNotEmpty)
          Text(
            meta!,
            style: AppTheme.sans(
              size: 12,
              weight: FontWeight.w600,
              color: t.textMute,
            ),
          ),
      ],
    );
  }
}

class _CreateChannelNameField extends StatelessWidget {
  const _CreateChannelNameField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.accent.withValues(alpha: 0.42), width: 2),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Text(
            '#',
            style: AppTheme.sans(
              size: 28,
              weight: FontWeight.w700,
              color: t.accent,
            ).copyWith(height: 1),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: '输入频道名称',
                hintStyle: AppTheme.sans(
                  size: 15,
                  weight: FontWeight.w400,
                  color: t.textMute,
                ),
              ),
              style: AppTheme.sans(
                size: 15,
                weight: FontWeight.w400,
                color: t.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateChannelAvatarPicker extends StatelessWidget {
  const _CreateChannelAvatarPicker({
    required this.previewBytes,
    required this.uploading,
    required this.onTap,
  });

  final Uint8List? previewBytes;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.surfaceHover,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 78,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: t.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (previewBytes == null)
                      Icon(
                        Symbols.add_photo_alternate,
                        color: t.accent,
                        size: 31,
                        fill: 1,
                      )
                    else
                      Image.memory(previewBytes!, fit: BoxFit.cover),
                    if (uploading)
                      ColoredBox(
                        color: t.text.withValues(alpha: 0.24),
                        child: Center(
                          child: SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: t.onAccent,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      previewBytes == null ? '选择头像' : '更换头像',
                      style: AppTheme.sans(
                        size: 15,
                        weight: FontWeight.w600,
                        color: t.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      uploading ? '头像上传中...' : '支持图片上传，作为频道展示头像',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.sans(
                        size: 12,
                        weight: FontWeight.w400,
                        color: t.textMute,
                      ).copyWith(height: 17 / 12),
                    ),
                  ],
                ),
              ),
              Icon(
                Symbols.chevron_right,
                color: t.text,
                size: 30,
                weight: 700,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _imageMimeTypeForName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.heic')) return 'image/heic';
  if (lower.endsWith('.heif')) return 'image/heif';
  return 'image/jpeg';
}

class _CreateChannelTypeTile extends StatelessWidget {
  const _CreateChannelTypeTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: selected ? t.accent.withValues(alpha: 0.10) : t.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 102,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? t.accent : t.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: selected
                      ? t.accent.withValues(alpha: 0.14)
                      : t.surfaceHover,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 23,
                  color: selected ? t.accent : t.textMute,
                  weight: 700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: AppTheme.sans(
                  size: 15,
                  weight: FontWeight.w600,
                  color: t.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppTheme.sans(
                  size: 12,
                  weight: FontWeight.w400,
                  color: t.textMute,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateChannelSwitchRow extends StatelessWidget {
  const _CreateChannelSwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTheme.sans(
                  size: 15,
                  weight: FontWeight.w500,
                  color: t.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppTheme.sans(
                  size: 12,
                  weight: FontWeight.w400,
                  color: t.textMute,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: t.onAccent,
          activeTrackColor: t.accent,
          inactiveThumbColor: t.textMute,
          inactiveTrackColor: t.surfaceHover,
        ),
      ],
    );
  }
}

class _CreateChannelSubmitButton extends StatelessWidget {
  const _CreateChannelSubmitButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.accent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 48,
          child: Center(
            child: Text(
              '创建频道',
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

class _ContactList extends ConsumerWidget {
  const _ContactList({required this.client});
  final Client client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn =
        ref.watch(authStateNotifierProvider).valueOrNull?.isLoggedIn ?? false;
    final useMockContacts = _mockAuthEnabled || !isLoggedIn;
    final syncCache = ref.watch(asSyncCacheProvider);
    final friendRequestReadState = ref.watch(friendRequestReadProvider);
    final acceptedContacts = syncCache.acceptedContacts;
    final pendingInvites = friendRequestReadState.unreadCountForRoomIds(
      _pendingFriendRequestRoomIds(client: client, syncCache: syncCache),
    );
    // 通讯录里只放"个人联系人"。Mock 数据里群组（mxid 以 # / ! 起头）和 AI bot
    // 排除——群组归「群聊」入口管。
    final mockContacts = MockData.friendContacts;

    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final contacts = useMockContacts
        ? mockContacts
            .map(
              (contact) => _ContactListEntry(
                name: contact.name,
                mxid: contact.mxid,
                avatarUrl: contact.avatarUrl,
              ),
            )
            .toList()
        : acceptedContacts.map((contact) {
            final peerMxid = contact.userId.trim();
            return _ContactListEntry(
              name: contactDisplayNameFromIdentity(
                mxid: peerMxid,
                displayName: contact.displayName,
                domain: contact.domain,
              ),
              mxid: peerMxid,
              avatarUrl: avatarHttpUrl(client, contact.avatarUrl),
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

class _ChannelExplorePage extends ConsumerStatefulWidget {
  const _ChannelExplorePage();

  @override
  ConsumerState<_ChannelExplorePage> createState() =>
      _ChannelExplorePageState();
}

class _ChannelExplorePageState extends ConsumerState<_ChannelExplorePage> {
  String _section = '已加入';
  String _contentType = '全部';

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(matrixClientProvider);
    final isLoggedIn =
        ref.watch(authStateNotifierProvider).valueOrNull?.isLoggedIn ?? false;
    final bootstrap = ref.watch(asSyncCacheProvider).bootstrap;
    final useRealChannels =
        !_mockAuthEnabled && isLoggedIn && bootstrap != null;
    final channels = useRealChannels
        ? ChannelInboxData.fromBootstrap(
            bootstrap,
            fallbackDomain: _clientServerName(client),
          )
        : _mockChannelItems();
    final joinedChannels = _channelFilteredItems(channels, _contentType);
    final discoverChannels = _channelFilteredItems(
      _discoverChannelItems(),
      _contentType,
    );
    final visibleChannels =
        _section == '已加入' ? joinedChannels : discoverChannels;
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );

    if (!_mockAuthEnabled && isLoggedIn && bootstrap == null) {
      return const _ChannelFrame(
        child: Center(
          child: _Empty(
            icon: Symbols.sync,
            title: '正在同步频道',
            subtitle: '请稍候',
          ),
        ),
      );
    }

    final topInset = MediaQuery.of(context).padding.top;
    return _ChannelFrame(
      child: Stack(
        children: [
          Positioned(
            left: 24,
            top: topInset + 22,
            width: 140,
            height: 28,
            child: Text(
              key: const ValueKey('channel_tab_title'),
              _homeTabTitle(l10n, 2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.sans(
                size: 20,
                weight: FontWeight.w600,
                color: _homeTextColor(context),
              ),
            ),
          ),
          Positioned(
            right: 24,
            top: topInset + 12,
            child: Row(
              children: [
                _ChannelTopCircleButton(
                  icon: Symbols.checklist,
                  badgeCount: _channelPendingCount(channels),
                  onTap: () => context.push('/channels/manage'),
                ),
                const SizedBox(width: 10),
                _ChannelSearchButton(
                  onTap: () => context.push('/channels/search'),
                ),
                const SizedBox(width: 10),
                _ChannelTopCircleButton(
                  key: const ValueKey('channel_post_button'),
                  icon: Symbols.add,
                  onTap: () => _showCreateChannelDialog(context, ref),
                ),
              ],
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            top: topInset + 92,
            height: 40,
            child: _ChannelSectionSwitch(
              key: const ValueKey('channel_filter_bar'),
              value: _section,
              onChanged: (value) => setState(() => _section = value),
            ),
          ),
          Positioned(
            left: 24,
            top: topInset + 148,
            height: 28,
            child: _ChannelTypeFilter(
              value: _contentType,
              onChanged: (value) => setState(() => _contentType = value),
            ),
          ),
          Positioned.fill(
            top: topInset + 202,
            child: visibleChannels.isEmpty
                ? _ChannelEmptyArea(selectedSection: _section)
                : _ChannelInboxList(
                    channels: visibleChannels,
                    mode: _section == '已加入'
                        ? _ChannelListMode.joined
                        : _ChannelListMode.discover,
                    onJoin: _section == '已加入' ? null : _handleDiscoverJoin,
                  ),
          ),
        ],
      ),
    );
  }

  void _handleDiscoverJoin(ChannelInboxItem channel) {
    final pending = channel.joinPolicy == asChannelJoinPolicyApproval;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(pending ? '已提交加入申请' : '已加入频道')),
    );
  }
}

class _ChannelFrame extends StatelessWidget {
  const _ChannelFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _homeBgColor(context),
      child: child,
    );
  }
}

class _ChannelSectionSwitch extends StatelessWidget {
  const _ChannelSectionSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.surfaceHigh,
        border: Border.all(color: t.border.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final label in _channelSections)
            Expanded(
              child: _ChannelSectionSegment(
                label: label,
                selected: label == value,
                onTap: () => onChanged(label),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChannelSectionSegment extends StatelessWidget {
  const _ChannelSectionSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: selected ? t.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox.expand(
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTheme.sans(
                size: 15,
                weight: FontWeight.w500,
                color: selected ? t.text : t.textMute,
              ).copyWith(height: 22 / 15),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelTypeFilter extends StatelessWidget {
  const _ChannelTypeFilter({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final label in _channelTypeFilters) ...[
          _ChannelTypePill(
            label: label,
            selected: label == value,
            onTap: () => onChanged(label),
          ),
          if (label != _channelTypeFilters.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _ChannelTypePill extends StatelessWidget {
  const _ChannelTypePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final bg = selected ? t.accent.withValues(alpha: 0.14) : t.surfaceHigh;
    final fg = selected ? t.accent : t.textMute;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: SizedBox(
          width: label == '全部' ? 48 : 50,
          height: 28,
          child: Center(
            child: Text(
              label,
              style: AppTheme.sans(
                size: 13,
                weight: FontWeight.w500,
                color: fg,
              ).copyWith(height: 18 / 13),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelSearchButton extends StatelessWidget {
  const _ChannelSearchButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ChannelTopCircleButton(
      key: const ValueKey('channel_search_button'),
      icon: Symbols.search,
      onTap: onTap,
    );
  }
}

class _ChannelTopCircleButton extends StatelessWidget {
  const _ChannelTopCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.surface,
      shape: const CircleBorder(),
      elevation: 14,
      shadowColor: t.text.withValues(alpha: 0.12),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: 39,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Icon(
                  icon,
                  size: 25,
                  color: t.text,
                ),
              ),
              if (badgeCount > 0)
                Positioned(
                  top: -2,
                  right: -1,
                  child: _ChannelActionBadge(count: badgeCount),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelActionBadge extends StatelessWidget {
  const _ChannelActionBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFFF5268),
        shape: BoxShape.circle,
      ),
      child: Text(
        _formatBadgeCount(count),
        style: AppTheme.sans(
          size: 11,
          weight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

const _channelSections = ['已加入', '频道列表'];
const _channelTypeFilters = ['全部', '文字', '帖子'];

enum _ChannelListMode { joined, discover }

List<ChannelInboxItem> _channelFilteredItems(
  List<ChannelInboxItem> channels,
  String category,
) {
  final sorted = switch (category) {
    '文字' => channels.where(_channelIsTextType).toList(),
    '帖子' => channels.where((channel) => !_channelIsTextType(channel)).toList(),
    _ => [...channels],
  };
  sorted.sort((a, b) {
    final aMs = a.latestAt?.millisecondsSinceEpoch ?? 0;
    final bMs = b.latestAt?.millisecondsSinceEpoch ?? 0;
    return bMs.compareTo(aMs);
  });
  return sorted;
}

bool _channelIsTextType(ChannelInboxItem channel) {
  final tags = channel.tags.map((tag) => tag.trim()).toSet();
  if (tags.contains('文字')) return true;
  if (tags.contains('帖子')) return false;
  return channel.name.contains('综合') ||
      channel.name.contains('前端') ||
      channel.name.contains('Matrix');
}

int _channelPendingCount(List<ChannelInboxItem> channels) {
  final count = channels.fold<int>(
    0,
    (sum, channel) => sum + channel.pendingJoinCount,
  );
  return count > 0 ? count : 1;
}

class _ChannelEmptyArea extends StatelessWidget {
  const _ChannelEmptyArea({required this.selectedSection});

  final String selectedSection;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 260,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Empty(
                icon: Symbols.campaign,
                title: '还没有频道',
                subtitle:
                    selectedSection == '频道列表' ? '暂时没有可加入的频道' : '加入频道后会显示在这里',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChannelInboxList extends StatelessWidget {
  const _ChannelInboxList({
    required this.channels,
    required this.mode,
    this.onJoin,
  });

  final List<ChannelInboxItem> channels;
  final _ChannelListMode mode;
  final ValueChanged<ChannelInboxItem>? onJoin;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 104),
      itemCount: channels.length,
      itemBuilder: (context, index) => _ChannelInboxTile(
        channel: channels[index],
        mode: mode,
        showDivider: index != channels.length - 1,
        onJoin: onJoin,
      ),
    );
  }
}

class _ChannelInboxTile extends StatelessWidget {
  const _ChannelInboxTile({
    required this.channel,
    required this.mode,
    required this.showDivider,
    this.onJoin,
  });

  final ChannelInboxItem channel;
  final _ChannelListMode mode;
  final bool showDivider;
  final ValueChanged<ChannelInboxItem>? onJoin;

  @override
  Widget build(BuildContext context) {
    final mutedColor = _homeMutedColor(context);
    final textColor = _homeTextColor(context);
    final borderColor = _homeBorderColor(context);
    return InkWell(
      onTap: () => context.push('/channel/${Uri.encodeComponent(channel.id)}'),
      child: SizedBox(
        height: 76,
        child: Row(
          children: [
            const SizedBox(width: 24),
            _ChannelAvatar(channel: channel, size: 44),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: showDivider
                      ? Border(
                          bottom: BorderSide(color: borderColor, width: 0.5),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '#${channel.name}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.sans(
                                      size: 14,
                                      weight: FontWeight.w500,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _ChannelKindBadge(
                                  label:
                                      _channelIsTextType(channel) ? '文字' : '帖子',
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 22,
                              child: Text(
                                channel.latestPreview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.sans(
                                  size: 12,
                                  weight: FontWeight.w400,
                                  color: mutedColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (mode == _ChannelListMode.joined)
                      SizedBox(
                        width: 48,
                        height: 76,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 18, bottom: 11),
                          child: Align(
                            alignment: Alignment.topRight,
                            child: Text(
                              _formatChannelTime(channel.latestAt),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: AppTheme.sans(
                                size: 12,
                                weight: FontWeight.w400,
                                color: mutedColor,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      _ChannelJoinButton(
                        channel: channel,
                        onTap: () => onJoin?.call(channel),
                      ),
                    const SizedBox(width: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelKindBadge extends StatelessWidget {
  const _ChannelKindBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3F8),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: AppTheme.sans(
          size: 11,
          weight: FontWeight.w800,
          color: const Color(0xFF758296),
        ).copyWith(height: 15 / 11),
      ),
    );
  }
}

class _ChannelJoinButton extends StatelessWidget {
  const _ChannelJoinButton({required this.channel, required this.onTap});

  final ChannelInboxItem channel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final approval = channel.joinPolicy == asChannelJoinPolicyApproval;
    return Material(
      color: approval ? const Color(0xFFFFF0D8) : const Color(0xFFDDF6FF),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 54,
          height: 31,
          child: Center(
            child: Text(
              approval ? '申请' : '加入',
              style: AppTheme.sans(
                size: 15,
                weight: FontWeight.w800,
                color: approval
                    ? const Color(0xFF9B5B00)
                    : const Color(0xFF0780B9),
              ).copyWith(height: 21 / 15),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelAvatar extends StatelessWidget {
  const _ChannelAvatar({required this.channel, required this.size});
  final ChannelInboxItem channel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bg = _channelAvatarColor(channel);
    final icon = _channelIcon(channel);
    final fg = _channelIconColor(channel);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color:
            _homeDark(context) ? context.tk.accent.withValues(alpha: 0.16) : bg,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: 27,
        color: fg,
        weight: 700,
      ),
    );
  }
}

Color _channelAvatarColor(ChannelInboxItem channel) {
  final name = channel.name;
  if (name.contains('新手') || name.contains('AI') || name.contains('知识')) {
    return const Color(0xFFE2F7EC);
  }
  return const Color(0xFFDDF6FF);
}

Color _channelIconColor(ChannelInboxItem channel) {
  final name = channel.name;
  if (name.contains('新手') || name.contains('AI') || name.contains('知识')) {
    return const Color(0xFF25A86D);
  }
  return const Color(0xFF198DC2);
}

IconData _channelIcon(ChannelInboxItem channel) {
  final name = channel.name;
  if (name.contains('综合')) return Symbols.tag;
  if (name.contains('新手')) return Symbols.question_mark;
  if (name.contains('前端')) return Symbols.code;
  if (name.contains('AI')) return Symbols.psychology;
  if (name.contains('Matrix')) return Symbols.hub;
  if (name.contains('知识')) return Symbols.forum;
  return Symbols.tag;
}

List<ChannelInboxItem> _mockChannelItems() {
  return [
    ChannelInboxItem(
      id: 'p2p-im',
      roomId: 'p2p-im',
      name: '综合讨论',
      domain: 'p2p-im.com',
      avatarUrl: '',
      latestPreview: '自由讨论、技术交流与闲聊',
      latestAt: _todayAt(9, 15),
      unreadCount: 0,
      isOwned: false,
      tags: const ['文字'],
    ),
    ChannelInboxItem(
      id: 'new-user',
      roomId: 'new-user',
      name: '新手问答',
      domain: 'p2p-im.com',
      avatarUrl: '',
      latestPreview: '问题交流和经验分享',
      latestAt: DateTime.now().subtract(const Duration(days: 1)),
      unreadCount: 0,
      isOwned: false,
      tags: const ['帖子'],
    ),
  ];
}

List<ChannelInboxItem> _discoverChannelItems() {
  return [
    ChannelInboxItem(
      id: 'frontend',
      roomId: 'frontend',
      name: '前端开发者',
      domain: 'p2p-im.com',
      avatarUrl: '',
      latestPreview: 'Web、跨端与工程化实践',
      latestAt: _todayAt(10, 30),
      unreadCount: 0,
      isOwned: false,
      tags: const ['文字'],
    ),
    ChannelInboxItem(
      id: 'ai-product',
      roomId: 'ai-product',
      name: 'AI 产品研究',
      domain: 'p2p-im.com',
      avatarUrl: '',
      latestPreview: '模型、Agent 与产品设计',
      latestAt: _todayAt(10, 20),
      unreadCount: 0,
      isOwned: false,
      tags: const ['帖子'],
      joinPolicy: asChannelJoinPolicyApproval,
    ),
    ChannelInboxItem(
      id: 'matrix-practice',
      roomId: 'matrix-practice',
      name: 'Matrix 实战',
      domain: 'p2p-im.com',
      avatarUrl: '',
      latestPreview: 'Matrix 房间、联邦与端到端加密实践',
      latestAt: _todayAt(10, 10),
      unreadCount: 0,
      isOwned: false,
      tags: const ['文字'],
    ),
    ChannelInboxItem(
      id: 'knowledge-qa',
      roomId: 'knowledge-qa',
      name: '知识问答',
      domain: 'p2p-im.com',
      avatarUrl: '',
      latestPreview: '沉淀问题和最佳答案',
      latestAt: _todayAt(10, 0),
      unreadCount: 0,
      isOwned: false,
      tags: const ['帖子'],
    ),
  ];
}

DateTime _todayAt(int hour, int minute) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, hour, minute);
}

String _formatChannelTime(DateTime? value) {
  if (value == null) return '';
  return _formatConvTime(value.millisecondsSinceEpoch);
}

String _clientServerName(Client client) {
  final userId = client.userID ?? '';
  final fromMxid = serverNameFromMxid(userId);
  if (fromMxid != null && fromMxid.isNotEmpty) return fromMxid;
  final homeserver = client.homeserver;
  if (homeserver != null && homeserver.host.isNotEmpty) return homeserver.host;
  return 'p2p-im.com';
}

class _MePage extends ConsumerStatefulWidget {
  const _MePage({required this.client});
  final Client client;

  @override
  ConsumerState<_MePage> createState() => _MePageState();
}

class _MePageState extends ConsumerState<_MePage> {
  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final client = widget.client;
    final userId = client.userID ?? '';
    final displayId = userId.isEmpty ? '@me:portal.agent-p2p.io' : userId;
    final localpart = _localpartFromMxid(displayId);
    final profileName = profile?.displayName?.trim();
    final personalProfile = ref.watch(personalProfileProvider);
    final draftName = personalProfile.displayName?.trim();
    final displayName = draftName?.isNotEmpty == true
        ? draftName!
        : profileName?.isNotEmpty == true
            ? profileName!
            : localpart;
    final avatarUrl = profileAvatarHttpUrl(profile, client) ?? MockAvatars.me;
    final uidUrl = _meUidUrl(client, displayId);

    return ColoredBox(
      color: _homeBgColor(context),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
          children: [
            _MeTopBar(
              onSettingsTap: () => context.push('/settings'),
            ),
            const SizedBox(height: 12),
            _MeProfileTile(
              displayId: displayId,
              displayName: displayName,
              uid: uidUrl,
              avatarUrl: avatarUrl,
              onAvatarTap: () => context.push('/me/profile'),
              onProfileTap: () => context.push('/me/profile'),
              onUidTap: () => _copyUidUrl(context, uidUrl),
              onQrTap: () => context.push('/me/qr'),
            ),
            const SizedBox(height: 34),
            _MeActionRow(
              assetName: _assetMeChannels,
              label: '我的频道',
              onTap: () => context.push('/channels/manage'),
            ),
            const SizedBox(height: 16),
            _MeActionRow(
              assetName: _assetMeFavorites,
              label: '赞/收藏',
              onTap: () => context.push('/me/favorites'),
            ),
            const SizedBox(height: 16),
            _MeActionRow(
              assetName: _assetMeComments,
              label: '评论',
              onTap: () => context.push('/me/comments'),
            ),
          ],
        ),
      ),
    );
  }
}

String _meUidUrl(Client client, String displayId) {
  final domain = serverNameFromMxid(displayId) ?? _clientServerName(client);
  final normalized = domain.trim().replaceFirst(RegExp(r'^https?://'), '');
  if (normalized.isEmpty) return displayId;
  return 'https://$normalized';
}

Future<void> _copyUidUrl(BuildContext context, String uidUrl) async {
  await Clipboard.setData(ClipboardData(text: uidUrl));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('已复制 UID')),
  );
}

class _MeTopBar extends StatelessWidget {
  const _MeTopBar({required this.onSettingsTap});

  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final textColor = _homeTextColor(context);
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: Text(
              '我的',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.sans(
                size: 20,
                weight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          _MeGlassIconButton(
            assetName: _assetMeSettings,
            onTap: onSettingsTap,
          ),
        ],
      ),
    );
  }
}

class _MeProfileTile extends StatelessWidget {
  const _MeProfileTile({
    required this.displayId,
    required this.displayName,
    required this.uid,
    required this.avatarUrl,
    required this.onAvatarTap,
    required this.onProfileTap,
    required this.onUidTap,
    required this.onQrTap,
  });

  final String displayId;
  final String displayName;
  final String uid;
  final String avatarUrl;
  final VoidCallback? onAvatarTap;
  final VoidCallback onProfileTap;
  final VoidCallback onUidTap;
  final VoidCallback onQrTap;

  @override
  Widget build(BuildContext context) {
    final textColor = _homeTextColor(context);
    final mutedColor = _homeMutedColor(context);
    return SizedBox(
      height: 60,
      child: Row(
        children: [
          GestureDetector(
            onTap: onAvatarTap,
            child: PortalAvatar(
              seed: displayId,
              size: 60,
              imageUrl: avatarUrl,
              shape: AvatarShape.squircle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    key: const ValueKey('me_profile_entry'),
                    onTap: onProfileTap,
                    borderRadius: BorderRadius.circular(6),
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.sans(
                        size: 16,
                        weight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onUidTap,
                    child: SizedBox(
                      height: 20,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'UID: $uid',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.sans(
                                size: 14,
                                color: mutedColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Symbols.content_copy,
                            size: 16,
                            color: context.tk.textMute,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            key: const ValueKey('me_domain_qr_button'),
            tooltip: '我的二维码',
            onPressed: onQrTap,
            icon: _assetIcon(_assetMeQr, size: 24, color: _meIconBlue),
          ),
        ],
      ),
    );
  }
}

class _MeActionRow extends StatelessWidget {
  const _MeActionRow({
    required this.assetName,
    required this.label,
    required this.onTap,
  });

  final String assetName;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final isDark = _homeDark(context);
    return Material(
      color: isDark ? t.surface : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _assetIcon(assetName, size: 24, color: _meIconBlue),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(
                      size: 16,
                      weight: FontWeight.w500,
                      color: _homeTextColor(context),
                    ).copyWith(height: 22 / 16),
                  ),
                ),
                Icon(
                  Symbols.chevron_right,
                  size: 24,
                  color: _homeMutedColor(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MeGlassIconButton extends StatelessWidget {
  const _MeGlassIconButton({
    required this.assetName,
    required this.onTap,
  });

  final String assetName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final isDark = _homeDark(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.12),
            blurRadius: 36,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Material(
            color: isDark
                ? t.surfaceHigh.withValues(alpha: 0.72)
                : Colors.white.withValues(alpha: 0.65),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: _assetIcon(assetName, size: 24, color: _meIconBlue),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: t.textMute),
          const SizedBox(height: 12),
          Text(
            title,
            style: AppTheme.sans(
              size: 14,
              color: t.text,
              weight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: AppTheme.sans(size: 12, color: t.textMute)),
        ],
      ),
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
