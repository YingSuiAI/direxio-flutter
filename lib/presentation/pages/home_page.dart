import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:matrix/matrix.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../channel/channel_inbox_data.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_bootstrap_store_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/friend_request_read_provider.dart';
import '../providers/local_message_order_provider.dart';
import '../providers/local_outbox_provider.dart';
import '../widgets/portal_avatar.dart';
import '../mock/mock_data.dart';
import '../mock/mock_channels.dart';
import '../../data/as_client.dart';
import '../../data/local_outbox_store.dart';
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
import '../widgets/avatar_adjust_sheet.dart';
import '../widgets/app_glass_background.dart';
import '../widgets/glass_list_tile.dart';
import '../widgets/m3/glass_header.dart';
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
const _assetMeHistory =
    'assets/resources/ic_profile_clear_chat__ic_profile_clear_chat.png';
const _meIconBlue = Color(0xFF3097CB);
const _bottomSearchTapSize = 56.0;
const _bottomSearchIconSize = 48.0;

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
  Timer? _asBootstrapRefreshTimer;
  String? _incomingCallRouteRoomId;
  String? _incomingGroupCallRouteRoomId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 订阅 client.onSync,任何 /sync 周期触发就重建,
    // 让会话列表的 lastEvent / notificationCount / 新房间 实时更新。
    final client = ref.read(matrixClientProvider);
    _attachVoiceCallController(client);
    _syncSub = client.onSync.stream.listen((_) {
      if (!mounted) return;
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
    final auth = ref.read(authStateNotifierProvider).valueOrNull;
    if (!(auth?.isLoggedIn ?? false)) return;
    if (!refreshExisting && ref.read(asSyncCacheProvider).bootstrap != null) {
      return;
    }

    _asBootstrapRefreshTimer = Timer(
      refreshExisting ? const Duration(milliseconds: 300) : Duration.zero,
      () {
        if (!mounted || _asBootstrapRefreshInFlight) return;
        _asBootstrapRefreshInFlight = true;
        unawaited(_refreshAsBootstrap());
      },
    );
  }

  void _finishAsBootstrapRefresh() {
    _asBootstrapRefreshInFlight = false;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refreshAsBootstrap() async {
    try {
      final bootstrap = await ref
          .read(asBootstrapRepositoryProvider)
          .refresh()
          .timeout(const Duration(seconds: 10));
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.copyWith(bootstrap: bootstrap),
          );
    } catch (e) {
      debugPrint('home bootstrap refresh failed: $e');
    } finally {
      _finishAsBootstrapRefresh();
    }
  }

  static const _tabTitles = ['Chats', '通讯录', '频道', '我的'];

  List<Widget> _headerActions(BuildContext context, Client client) {
    switch (_tab) {
      case 0:
      case 1:
        return [
          GlassHeaderButton(
            icon: Symbols.search,
            onTap: () => context.push('/search'),
          ),
          const _HomePlusMenuButton(),
        ];
      case 2:
        return [
          GlassHeaderButton(
            icon: Symbols.search,
            onTap: () => context.push('/channels/search'),
          ),
          const _HomePlusMenuButton(),
        ];
      case 3:
        return [
          GlassHeaderButton(
            icon: Symbols.menu,
            onTap: () => context.push('/me/menu'),
          ),
        ];
      default:
        return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(matrixClientProvider);
    final authState = ref.watch(authStateNotifierProvider);
    final syncCache = ref.watch(asSyncCacheProvider);
    final friendRequestReadState = ref.watch(friendRequestReadProvider);
    final friendRequestUnreadCount = friendRequestReadState
        .unreadCountForRoomIds(_pendingFriendRequestRoomIds(
      client: client,
      syncCache: syncCache,
    ));
    final t = context.tk;
    if (authState.valueOrNull?.isLoggedIn ?? false) {
      _scheduleAsBootstrapRefreshIfNeeded();
      _attachVoiceCallController(client);
    }

    final unreadTotal = _homeUnreadTotal(client, syncCache);

    return Scaffold(
      backgroundColor: _homeBg,
      body: Column(
        children: [
          if (_tab == 0)
            _ChatsTopBar(
              unreadCount: unreadTotal,
              onPlusTap: () => _handleHomePlusTap(context, ref),
            )
          else if (_tab == 1)
            _HomeTitleTopBar(
              title: _tabTitles[_tab],
              onPlusTap: () => _handleHomePlusTap(context, ref),
            )
          else if (_tab != 2 && _tab != 3)
            GlassHeader.primary(
              title: _tabTitles[_tab],
              actions: _headerActions(context, client),
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
                        child: _DetailPlaceholder(tabTitle: _tabTitles[_tab])),
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
            label: 'Chats',
          ),
          _HomeNavItem(
            iconAsset: _iconTabContacts,
            label: '通讯录',
            badge: friendRequestUnreadCount > 0
                ? _formatBadgeCount(friendRequestUnreadCount)
                : null,
          ),
          const _HomeNavItem(
            iconAsset: _iconTabChannel,
            label: '频道',
          ),
          const _HomeNavItem(
            iconAsset: _iconTabMe,
            activeIconAsset: _assetMeTabSelected,
            inactiveIconAsset: _assetMeTabNormal,
            label: '我的',
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
    return Container(
      height: topInset + 56,
      padding: EdgeInsets.fromLTRB(16, topInset + 4, 16, 4),
      color: _homeBg,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.sans(
                size: 20,
                weight: FontWeight.w600,
                color: _homeText,
              ),
            ),
          ),
          _GlassCircleButton(
            icon: Symbols.add,
            size: 40,
            iconSize: 24,
            onTap: onPlusTap,
          ),
        ],
      ),
    );
  }
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

class _ChatsTopBar extends StatelessWidget {
  const _ChatsTopBar({
    required this.unreadCount,
    required this.onPlusTap,
  });

  final int unreadCount;
  final VoidCallback onPlusTap;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final label = unreadCount > 0 ? 'Chats($unreadCount)' : 'Chats';
    return Container(
      height: topInset + 56,
      padding: EdgeInsets.fromLTRB(16, topInset + 4, 16, 4),
      color: _homeBg,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.sans(
                size: 20,
                weight: FontWeight.w600,
                color: _homeText,
              ),
            ),
          ),
          _GlassCircleButton(
            icon: Symbols.add,
            size: 40,
            iconSize: 25,
            onTap: onPlusTap,
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

class _HomePlusMenuButton extends ConsumerWidget {
  const _HomePlusMenuButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassHeaderButton(
      icon: Symbols.add,
      onTap: () => _handleHomePlusTap(context, ref),
    );
  }
}

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('扫一扫功能待接入')));
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F7).withValues(alpha: 0.80),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF7F7F7)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
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
              color: _homeText,
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
                  color: _homeText,
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
    required this.label,
    this.badge,
    this.activeIconAsset,
    this.inactiveIconAsset,
  });

  final String iconAsset;
  final String label;
  final String? badge;
  final String? activeIconAsset;
  final String? inactiveIconAsset;
}

class _HomeBottomBar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return SizedBox(
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
                      _homeBg.withValues(alpha: 0.0),
                      _homeBg.withValues(alpha: 0.92),
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
              items: items,
              currentIndex: currentIndex,
              onTap: onTap,
            ),
          ),
          Positioned(
            right: 16,
            bottom: bottomInset + 4,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSearchTap,
              child: SizedBox(
                width: _bottomSearchTapSize,
                height: _bottomSearchTapSize,
                child: Center(
                  child: SvgPicture.asset(
                    _iconBottomSearchTg,
                    width: _bottomSearchIconSize,
                    height: _bottomSearchIconSize,
                  ),
                ),
              ),
            ),
          ),
        ],
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
    return AppGlassPanel(
      borderRadius: BorderRadius.circular(276),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final active = index == currentIndex;
            return SizedBox(
              width: index == 0 ? 70 : 71,
              height: 49,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => onTap(index),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (active)
                      Positioned.fill(
                        right: index == 0 ? 0 : 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.76),
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
                              size: 24,
                              color: item.activeIconAsset == null &&
                                      item.inactiveIconAsset == null
                                  ? active
                                      ? t.accent
                                      : _homeText
                                  : null,
                            ),
                            if (item.badge != null)
                              Positioned(
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
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.sans(
                            size: 10,
                            weight: FontWeight.w600,
                            color: active ? t.accent : _homeText,
                          ).copyWith(height: 1.2),
                        ),
                      ],
                    ),
                  ],
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
  if (assetName.toLowerCase().endsWith('.svg')) {
    return SvgPicture.asset(
      assetName,
      width: size,
      height: size,
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
            child: Icon(icon, size: iconSize, color: _homeText),
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
    final syncCache = ref.watch(asSyncCacheProvider);
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
      final convs = MockData.conversations.toList();
      return ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 96),
        itemCount: convs.length,
        itemBuilder: (context, i) {
          final c = convs[i];
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
            onTap: () => context.push('/chat/${c.id}'),
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

    if (visibleConversations.isEmpty) {
      return const _Empty(
        icon: Symbols.forum,
        title: '还没有会话',
        subtitle: '去添加联系人，或等待 Agent 会话创建完成',
      );
    }

    final sortedConversations = [...visibleConversations]..sort((a, b) {
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

    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 96),
      itemCount: sortedConversations.length,
      itemBuilder: (context, i) {
        final conversation = sortedConversations[i];
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
              : _conversationDisplayName(conversation),
          lastMessage: lastMessage,
          time: previewTime == null
              ? ''
              : _formatConvTime(previewTime.millisecondsSinceEpoch),
          unread: _conversationUnreadCount(conversation, room),
          isAgent: conversation.isAgent,
          isGroup: conversation.isGroup,
          avatarUrl: _conversationAvatarUrl(client, conversation, room),
          onTap: () => conversation.isGroup
              ? context
                  .push('/group/${Uri.encodeComponent(conversation.roomId)}')
              : context
                  .push('/chat/${Uri.encodeComponent(conversation.roomId)}'),
        );
      },
    );
  }
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
      (room == null ? null : roomAvatarHttpUrl(room)) ??
      _directPeerMemberAvatarUrl(client, room, contact?.userId);
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

String _conversationDisplayName(_VisibleConversation conversation) {
  final group = conversation.group;
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

/// 会话列表行 —— 对齐 Figma node 53:505。
/// 头像 42×42、圆角 8、头像与内容间距 8，右侧时间/未读固定宽度。
class _ConvRow extends StatelessWidget {
  const _ConvRow({
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unread,
    required this.onTap,
    this.isAgent = false,
    this.isGroup = false,
    this.avatarUrl,
  });
  final String name;
  final String lastMessage;
  final String time;
  final int unread;
  final VoidCallback onTap;
  final bool isAgent;
  final bool isGroup;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    Offset rcPos = Offset.zero;
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
      onSecondaryTap: () => _showChatCtxMenu(context, rcPos, name),
      onLongPressStart: (d) {
        rcPos = d.globalPosition;
        _showChatCtxMenu(context, rcPos, name);
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
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: _homeBorder, width: 0.5),
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
                                          color: _homeText,
                                        ),
                                      ),
                                    ),
                                    if (isAgent) ...[
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Symbols.smart_toy,
                                        size: 14,
                                        color: _homeMuted,
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
                                    color: _homeMuted,
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
                                    color: _homeMuted,
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

void _showChatCtxMenu(BuildContext context, Offset pos, String name) {
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
          child: _ChatCtxMenuCard(name: name),
        ),
      ],
    ),
    transitionBuilder: (ctx, a, _, child) =>
        FadeTransition(opacity: a, child: child),
  );
}

class _ChatCtxMenuCard extends StatelessWidget {
  const _ChatCtxMenuCard({required this.name});
  final String name;

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
            _row(context, Symbols.push_pin, '置顶', () {
              Navigator.of(context).pop();
              _toast(context, '已置顶「$name」');
            }),
            const Divider(
              height: 1,
              color: _divider,
              indent: 16,
              endIndent: 16,
            ),
            _row(context, Symbols.visibility_off, '不显示', () {
              Navigator.of(context).pop();
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
  final nameCtrl = TextEditingController();
  final topicCtrl = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('创建频道'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: '频道名称'),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: topicCtrl,
            decoration: const InputDecoration(
              labelText: '频道简介（可选）',
              hintText: '展示在频道列表里',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('创建'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;
  final name = nameCtrl.text.trim();
  if (name.isEmpty) return;

  try {
    await ref.read(asClientProvider).createChannel(
          name: name,
          topic: topicCtrl.text.trim(),
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

    final contactCount =
        useMockContacts ? mockContacts.length : acceptedContacts.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 96),
      children: [
        _ActionSection(
          children: [
            _SectionAction(
              iconAsset: _iconMenuAddFriend,
              label: '新朋友',
              badge:
                  pendingInvites > 0 ? _formatBadgeCount(pendingInvites) : null,
              onTap: () => context.push('/requests'),
            ),
            _SectionAction(
              iconAsset: _iconMenuCreateGroup,
              label: '群聊',
              onTap: () => context.push('/groups'),
            ),
            _SectionAction(
              iconAsset: _iconTabContacts,
              label: '关注',
              onTap: () => context.push('/follows'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '联系人 ($contactCount)',
            style: AppTheme.sans(
              size: 12,
              color: _homeMuted,
              weight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (!useMockContacts)
          _ActionSection(
            children: acceptedContacts.map((contact) {
              final peerMxid = contact.userId.trim();
              return _ContactEntryTile(
                name: contactDisplayNameFromIdentity(
                  mxid: peerMxid,
                  displayName: contact.displayName,
                  domain: contact.domain,
                ),
                subtitle: peerMxid,
                avatarUrl: avatarHttpUrl(client, contact.avatarUrl),
                onTap: () {
                  if (peerMxid.isNotEmpty) {
                    context.push(
                      '/contact/${Uri.encodeComponent(peerMxid)}',
                    );
                  }
                },
              );
            }).toList(),
          )
        else
          _ActionSection(
            children: mockContacts
                .map(
                  (c) => _ContactEntryTile(
                    name: c.name,
                    subtitle: c.mxid,
                    avatarUrl: c.avatarUrl,
                    onTap: () =>
                        context.push('/contact/${Uri.encodeComponent(c.mxid)}'),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class HomeSearchBox extends StatelessWidget {
  const HomeSearchBox({super.key, required this.hint, required this.onTap});
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.surfaceHover,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(Symbols.search, size: 18, color: t.textMute),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hint,
                  style: AppTheme.sans(size: 14, color: t.textMute),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionSection extends StatelessWidget {
  const _ActionSection({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const _Empty(
        icon: Symbols.person,
        title: '还没有联系人',
        subtitle: '添加联系人后会显示在这里',
      );
    }
    return Column(children: children);
  }
}

class _SectionAction extends StatelessWidget {
  const _SectionAction({
    required this.iconAsset,
    required this.label,
    required this.onTap,
    this.badge,
  });

  final String iconAsset;
  final String label;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return _ContactFlatRow(
      onTap: onTap,
      leading: Container(
        width: _conversationTileAvatarSize,
        height: _conversationTileAvatarSize,
        decoration: BoxDecoration(
          color: const Color(0xFFE8F3FF),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: _DesignAssetIcon(
          assetName: iconAsset,
          size: 22,
          color: const Color(0xFF0066A8),
        ),
      ),
      title: label,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge != null) ...[
            Container(
              key: ValueKey('section_action_badge_$label'),
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
            const SizedBox(width: 8),
          ],
          const Icon(Symbols.chevron_right, size: 22, color: _homeMuted),
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
    this.subtitle,
    this.trailing,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                  height: subtitle == null ? 56 : 64,
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: _homeBorder, width: 0.5),
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
                                weight: FontWeight.w600,
                                color: _homeText,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.sans(
                                  size: 12,
                                  color: _homeMuted,
                                ),
                              ),
                            ],
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
    this.subtitle,
    this.avatarUrl,
  });

  final String name;
  final String? subtitle;
  final VoidCallback onTap;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return _ContactFlatRow(
      onTap: onTap,
      leading: SizedBox(
        width: _conversationTileAvatarSize,
        height: _conversationTileAvatarSize,
        child: PortalAvatar(
          seed: name,
          size: _conversationTileAvatarSize,
          imageUrl: avatarUrl,
          shape: AvatarShape.squircle,
        ),
      ),
      title: name,
      subtitle: subtitle,
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
  String _category = '全部';

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
    final categories = ChannelInboxData.categories(channels);
    final selectedCategory = categories.contains(_category) ? _category : '全部';
    final visibleChannels = ChannelInboxData.filtered(
      channels,
      selectedCategory,
    );

    if (!_mockAuthEnabled && isLoggedIn && bootstrap == null) {
      return const _Empty(
        icon: Symbols.sync,
        title: '正在同步频道',
        subtitle: '请稍候',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
      children: [
        SizedBox(
          height: 38,
          child: ListView.separated(
            key: const ValueKey('channel_category_strip'),
            padding: const EdgeInsets.symmetric(
              horizontal: glassListTileHorizontalMargin,
            ),
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, i) {
              final category = categories[i];
              return _ChannelCategoryChip(
                label: category,
                selected: category == selectedCategory,
                onTap: () => setState(() => _category = category),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemCount: categories.length,
          ),
        ),
        const SizedBox(height: 10),
        if (visibleChannels.isEmpty)
          _ChannelEmptyArea(selectedCategory: selectedCategory)
        else
          _ChannelInboxList(channels: visibleChannels),
      ],
    );
  }
}

class _ChannelEmptyArea extends StatelessWidget {
  const _ChannelEmptyArea({required this.selectedCategory});

  final String selectedCategory;

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
                    selectedCategory == '我的频道' ? '创建频道后会显示在这里' : '加入频道后会显示在这里',
              ),
              if (selectedCategory != '我的频道') ...[
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: () => context.push('/channels/search'),
                  icon: const Icon(Symbols.search),
                  label: const Text('搜索频道'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ChannelInboxList extends StatelessWidget {
  const _ChannelInboxList({required this.channels});
  final List<ChannelInboxItem> channels;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      color: t.surface,
      child: Column(
        children: [
          for (var i = 0; i < channels.length; i++) ...[
            _ChannelInboxTile(channel: channels[i]),
            if (i != channels.length - 1)
              Divider(
                height: 1,
                indent: 76,
                color: t.border.withValues(alpha: 0.16),
              ),
          ],
        ],
      ),
    );
  }
}

class _ChannelInboxTile extends StatelessWidget {
  const _ChannelInboxTile({required this.channel});
  final ChannelInboxItem channel;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return InkWell(
      onTap: () => context.push('/channel/${Uri.encodeComponent(channel.id)}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _ChannelAvatar(channel: channel, size: 48),
            const SizedBox(width: 12),
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
                            size: 16,
                            weight: FontWeight.w600,
                            color: t.text,
                          ),
                        ),
                      ),
                      if (channel.isOwned) ...[
                        const SizedBox(width: 6),
                        const _ChannelOwnerBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    channel.latestPreview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(size: 14, color: t.textMute),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatChannelTime(channel.latestAt),
                  style: AppTheme.sans(size: 12, color: t.textMute),
                ),
                const SizedBox(height: 7),
                if (channel.unreadCount > 0)
                  _ChannelUnreadNumber(channel: channel)
                else
                  const SizedBox(height: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelUnreadNumber extends StatelessWidget {
  const _ChannelUnreadNumber({required this.channel});

  final ChannelInboxItem channel;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SizedBox(
      height: 18,
      child: Text(
        _formatBadgeCount(channel.unreadCount),
        key: ValueKey('channel_unread_count_${channel.id}'),
        textAlign: TextAlign.right,
        textHeightBehavior: const TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
        ),
        style: AppTheme.sans(
          size: 12,
          weight: FontWeight.w600,
          color: t.textMute.withValues(alpha: 0.74),
        ).copyWith(height: 1),
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

List<ChannelInboxItem> _mockChannelItems() {
  return MockChannels.items
      .map(
        (channel) => ChannelInboxItem(
          id: channel.id,
          roomId: channel.id,
          name: channel.name,
          domain: channel.domain,
          avatarUrl: '',
          latestPreview: channel.latestMessage,
          latestAt: _mockChannelDateTime(channel.latestAt),
          unreadCount: channel.unreadCount,
          isOwned: channel.isOwned,
          tags: channel.tags,
        ),
      )
      .toList();
}

DateTime? _mockChannelDateTime(int value) {
  final raw = value.toString().padLeft(12, '0');
  if (raw.length != 12) return null;
  return DateTime.tryParse(
    '${raw.substring(0, 4)}-${raw.substring(4, 6)}-${raw.substring(6, 8)} '
    '${raw.substring(8, 10)}:${raw.substring(10, 12)}:00',
  );
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

class _ChannelOwnerBadge extends StatelessWidget {
  const _ChannelOwnerBadge();

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: t.surfaceHover,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '我的',
        style: AppTheme.sans(
          size: 10,
          weight: FontWeight.w600,
          color: t.textMute,
        ),
      ),
    );
  }
}

class _ChannelCategoryChip extends StatelessWidget {
  const _ChannelCategoryChip({
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
      color: selected ? t.accent : t.surfaceHover,
      borderRadius: BorderRadius.circular(9999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9999),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTheme.sans(
              size: 13,
              weight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? t.onAccent : t.textMute,
            ),
          ),
        ),
      ),
    );
  }
}

class _MePage extends ConsumerStatefulWidget {
  const _MePage({required this.client});
  final Client client;

  @override
  ConsumerState<_MePage> createState() => _MePageState();
}

class _MePageState extends ConsumerState<_MePage> {
  bool _avatarBusy = false;

  Future<void> _pickAvatar() async {
    if (_avatarBusy) return;

    try {
      setState(() => _avatarBusy = true);
      final xFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
        maxWidth: 2048,
        maxHeight: 2048,
        requestFullMetadata: false,
      );
      if (xFile == null) return;

      final bytes = await xFile.readAsBytes();
      if (!mounted) return;
      await showAvatarAdjustSheet(
        context,
        imageBytes: bytes,
        onConfirm: (adjustedBytes) async {
          try {
            final file = MatrixFile(
              bytes: adjustedBytes,
              name: 'avatar.png',
              mimeType: 'image/png',
            );
            await widget.client.setAvatar(file);
            ref.invalidate(currentUserProfileProvider);
            await ref.read(currentUserProfileProvider.future);
            ref.invalidate(appWarmupProvider);
            unawaited(ref.read(appWarmupProvider.future));
          } catch (e) {
            throw StateError(_avatarErrorText(e));
          }
        },
      );
    } catch (e) {
      debugPrint('Avatar update failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_avatarErrorText(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  bool _isTokenFailure(MatrixException error) {
    return error.errcode == 'M_UNKNOWN_TOKEN' ||
        error.errcode == 'M_MISSING_TOKEN' ||
        error.response?.statusCode == 401;
  }

  String _avatarErrorText(Object error) {
    if (error is FileTooBigMatrixException) {
      return '图片太大，请换一张 10MB 内的图片';
    }
    if (error is MatrixException && _isTokenFailure(error)) {
      return '登录状态已过期，请重新登录后再试';
    }
    if (error is StateError) return error.message;
    return '头像更新失败: $error';
  }

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
    final domain = _domainFromMxid(displayId);
    final avatarUrl = profileAvatarHttpUrl(profile, client) ?? MockAvatars.me;
    final uid = localpart.isEmpty ? displayId : localpart;

    return ColoredBox(
      color: _homeBg,
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
              uid: uid,
              avatarUrl: avatarUrl,
              avatarBusy: _avatarBusy,
              onAvatarTap: _avatarBusy ? null : _pickAvatar,
              onProfileTap: () => context.push('/me/profile'),
              onQrTap: () => _showDomainQrDialog(context, domain, displayId),
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
            const SizedBox(height: 16),
            _MeActionRow(
              assetName: _assetMeHistory,
              label: '浏览记录',
              onTap: () => context.push('/me/history'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeTopBar extends StatelessWidget {
  const _MeTopBar({required this.onSettingsTap});

  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
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
                color: const Color(0xFF333333),
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
    required this.avatarBusy,
    required this.onAvatarTap,
    required this.onProfileTap,
    required this.onQrTap,
  });

  final String displayId;
  final String displayName;
  final String uid;
  final String avatarUrl;
  final bool avatarBusy;
  final VoidCallback? onAvatarTap;
  final VoidCallback onProfileTap;
  final VoidCallback onQrTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Row(
        children: [
          GestureDetector(
            onTap: onAvatarTap,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PortalAvatar(
                  seed: displayId,
                  size: 60,
                  imageUrl: avatarUrl,
                  shape: AvatarShape.squircle,
                ),
                if (avatarBusy)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(13.5),
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.24),
                      child: const SizedBox(
                        width: 60,
                        height: 60,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: onProfileTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.sans(
                        size: 16,
                        weight: FontWeight.w600,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'UID $uid',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.sans(
                        size: 14,
                        color: const Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
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
    return Material(
      color: Colors.white,
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
                      color: const Color(0xFF262628),
                    ).copyWith(height: 22 / 16),
                  ),
                ),
                const Icon(
                  Symbols.chevron_right,
                  size: 24,
                  color: Colors.black,
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
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 36,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Material(
            color: Colors.white.withValues(alpha: 0.65),
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

String _domainFromMxid(String mxid) {
  final colon = mxid.indexOf(':');
  if (colon == -1 || colon == mxid.length - 1) return '未连接域名';
  return mxid.substring(colon + 1);
}

void _showDomainQrDialog(BuildContext context, String domain, String userId) {
  final t = context.tk;
  final payload = Uri(
    scheme: 'p2pim',
    host: 'add-contact',
    queryParameters: {'mxid': userId, 'domain': domain},
  ).toString();

  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '我的域名二维码',
              style: AppTheme.sans(
                size: 18,
                weight: FontWeight.w700,
                color: t.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '对方扫一扫即可添加好友',
              style: AppTheme.sans(size: 13, color: t.textMute),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: QrImageView(
                data: payload,
                version: QrVersions.auto,
                size: 188,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              userId,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.mono(size: 12, color: t.textMute),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('完成'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
