import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../theme/design_tokens.dart';
import '../../presentation/pages/login_page.dart';
import '../../presentation/pages/init_page.dart';
import '../../presentation/pages/setup_scan_page.dart';
import '../../presentation/pages/onboarding_password_page.dart';
import '../../presentation/pages/home_page.dart';
import '../../presentation/pages/chat_page.dart';
import '../../presentation/pages/chat_info_page.dart';
import '../../presentation/pages/room_search_page.dart';
import '../../presentation/pages/group_info_page.dart';
import '../../presentation/pages/group_chat_page.dart';
import '../../presentation/pages/contact_detail_page.dart';
import '../../presentation/pages/contact_home_page.dart';
import '../../presentation/pages/contact_channels_page.dart';
import '../../presentation/pages/add_contact_page.dart';
import '../../presentation/pages/add_contact_detail_page.dart';
import '../../presentation/pages/add_contact_verification_page.dart';
import '../../presentation/pages/about_us_page.dart';
import '../../presentation/pages/requests_page.dart';
import '../../presentation/pages/qr_scanner_page.dart';
import '../../presentation/pages/group_detail_page.dart';
import '../../presentation/pages/group_manage_page.dart';
import '../../presentation/pages/groups_list_page.dart';
import '../../presentation/pages/follows_list_page.dart';
import '../../presentation/pages/me_account_page.dart';
import '../../presentation/pages/me_notifications_page.dart';
import '../../presentation/pages/me_menu_page.dart';
import '../../presentation/pages/me_qr_page.dart';
import '../../presentation/pages/profile_info_page.dart';
import '../../presentation/pages/blacklist_page.dart';
import '../../presentation/pages/call_page.dart';
import '../../presentation/pages/group_call_page.dart';
import '../../presentation/pages/group_call_member_select_page.dart';
import '../../presentation/pages/settings_page.dart';
import '../../presentation/pages/search_page.dart';
import '../../presentation/pages/channel_search_page.dart';
import '../../presentation/pages/channel_page.dart';
import '../../presentation/pages/channel_detail_info_page.dart';
import '../../presentation/pages/channel_info_page.dart';
import '../../presentation/pages/channel_post_create_page.dart';
import '../../presentation/pages/channel_post_detail_page.dart';
import '../../presentation/pages/channel_management_page.dart';
import '../../presentation/channel/channel_home_tab.dart';
import '../../presentation/channel/channel_share.dart';
import '../../presentation/pages/mcp_permission_page.dart';
import '../../presentation/pages/mcp_policy_edit_page.dart';
import '../../presentation/providers/as_sync_cache_provider.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../data/setup_payload.dart';

part 'app_router.g.dart';

const _callAutotestEnabled = bool.fromEnvironment(
  'P2P_CALL_AUTOTEST',
  defaultValue: false,
);
const _callAutotestInitialRouteFileName = 'p2p_initial_route.txt';
String? _pendingCallAutotestInitialRoute;

String _channelConversationRoomId(Ref ref, String rawChannelId) {
  final channelId = rawChannelId.trim();
  if (channelId.isEmpty) return rawChannelId;
  final channels =
      ref.read(asSyncCacheProvider).bootstrap?.channels ?? const [];
  for (final channel in channels) {
    final roomId = channel.roomId.trim();
    if (roomId.isEmpty) continue;
    if (channel.channelId.trim() == channelId || roomId == channelId) {
      return roomId;
    }
  }
  return channelId;
}

enum PortalRouteTransition { slide, chatEntranceOnly }

PortalRouteTransition routeTransitionForLocation(String location) {
  final path = Uri.tryParse(location)?.path ?? location;
  if (path.startsWith('/chat/') || path.startsWith('/group/')) {
    return PortalRouteTransition.chatEntranceOnly;
  }
  return PortalRouteTransition.slide;
}

/// 横向滑入转场 —— 对齐设计稿 .screen translateX 动画。
/// 新页从右滑入，旧页同时左移 28%（视差），320ms。
CustomTransitionPage<void> _slidePage(Widget child) {
  return CustomTransitionPage<void>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    child: child,
    transitionsBuilder: (context, animation, secondary, child) {
      const curve = Curves.easeInOutCubic;
      final inSlide = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: curve));
      final outSlide = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.28, 0),
      ).animate(CurvedAnimation(parent: secondary, curve: curve));
      return SlideTransition(
        position: outSlide,
        child: SlideTransition(position: inSlide, child: child),
      );
    },
  );
}

Page<void> _chatEntrancePage(Widget child) {
  return NoTransitionPage<void>(child: child);
}

Page<void> _pageForLocation(String location, Widget child) {
  return switch (routeTransitionForLocation(location)) {
    PortalRouteTransition.chatEntranceOnly => _chatEntrancePage(child),
    PortalRouteTransition.slide => _slidePage(child),
  };
}

String? authRedirectLocation({
  required bool callAutotestEnabled,
  required bool isAuthLoading,
  required bool isLoggedIn,
  bool requiresProfileSetup = false,
  required String matchedLocation,
  required Uri uri,
}) {
  if (isAuthLoading) {
    return matchedLocation == '/restore' ? null : '/restore';
  }

  final isLoginRoute = matchedLocation == '/login' ||
      matchedLocation == '/restore' ||
      matchedLocation == '/init' ||
      matchedLocation == '/setup/scan' ||
      matchedLocation == '/setup/password';

  if (!isLoggedIn && matchedLocation == '/restore') return '/login';
  if (!isLoggedIn && !isLoginRoute) return '/login';
  if (isLoggedIn && requiresProfileSetup) {
    return matchedLocation == '/init' ? null : '/init';
  }
  if (isLoggedIn && matchedLocation == '/restore') {
    return callAutotestRestoreNextRoute(
          callAutotestEnabled: callAutotestEnabled,
          uri: uri,
        ) ??
        '/home';
  }
  if (isLoggedIn && isLoginRoute) return '/home';
  return null;
}

String? callAutotestRestoreNextRoute({
  required bool callAutotestEnabled,
  required Uri uri,
}) {
  if (!callAutotestEnabled) return null;
  final next = uri.queryParameters['next']?.trim();
  if (next == null || next.isEmpty || !next.startsWith('/')) return null;
  final path = Uri.tryParse(next)?.path ?? next;
  if (path.startsWith('/group-call/') ||
      path.startsWith('/group-video-call/')) {
    return next;
  }
  return null;
}

String initialAppLocation({
  required bool callAutotestEnabled,
  required Map<String, String> environment,
  required List<String> arguments,
  String? routeFileContent,
}) {
  final injectedRoute = callAutotestInitialRouteFromInputs(
    environment: environment,
    arguments: arguments,
    routeFileContent: routeFileContent,
  );
  if (callAutotestEnabled) {
    debugPrint(
      'p2p-call-autotest-initial injected=${injectedRoute ?? "<none>"} '
      'route_file=${routeFileContent != null}',
    );
  }
  if (callAutotestEnabled &&
      injectedRoute != null &&
      injectedRoute.startsWith('/') &&
      callAutotestRestoreNextRoute(
            callAutotestEnabled: true,
            uri:
                Uri(path: '/restore', queryParameters: {'next': injectedRoute}),
          ) !=
          null) {
    return '/restore?next=${Uri.encodeComponent(injectedRoute)}';
  }
  return '/restore';
}

String? callAutotestInitialRouteFromInputs({
  required Map<String, String> environment,
  required List<String> arguments,
  String? routeFileContent,
}) {
  final fromArgument = arguments
      .where((argument) => argument.startsWith('--p2p-initial-route='))
      .map((argument) => argument.substring('--p2p-initial-route='.length))
      .firstOrNull
      ?.trim();
  if (fromArgument != null && fromArgument.isNotEmpty) return fromArgument;
  final fromFile = routeFileContent?.trim();
  if (fromFile != null && fromFile.isNotEmpty) return fromFile;
  return environment['P2P_INITIAL_ROUTE']?.trim();
}

String? rememberCallAutotestInitialRoute({
  required String? previousRoute,
  required String? consumedRoute,
}) {
  final route = consumedRoute?.trim();
  if (route != null && route.isNotEmpty) return route;
  return previousRoute;
}

String? consumeCallAutotestInitialRouteFile() {
  if (kIsWeb) {
    return null;
  }
  try {
    final file = io.File(
      '${io.Directory.systemTemp.path}/$_callAutotestInitialRouteFileName',
    );
    if (!file.existsSync()) {
      debugPrint('p2p-call-autotest-route-file-missing ${file.path}');
      return null;
    }
    final content = file.readAsStringSync();
    file.deleteSync();
    debugPrint('p2p-call-autotest-route-file-consumed ${file.path}');
    return content;
  } catch (_) {
    return null;
  }
}

Map<String, String> appRouterEnvironment() {
  if (!kIsWeb) {
    return io.Platform.environment;
  }
  const initialRoute = String.fromEnvironment('P2P_INITIAL_ROUTE');
  if (initialRoute.trim().isEmpty) {
    return const {};
  }
  return const {'P2P_INITIAL_ROUTE': initialRoute};
}

List<String> appRouterExecutableArguments() {
  if (kIsWeb) {
    return const [];
  }
  return io.Platform.executableArguments;
}

int _homeInitialTabFromQuery(String? tab) {
  return switch (tab?.trim().toLowerCase()) {
    'contacts' || 'contact' || '1' => 1,
    'channels' || 'channel' || '2' => 2,
    'me' || 'mine' || 'profile' || '3' => 3,
    _ => 0,
  };
}

@riverpod
GoRouter appRouter(Ref ref) {
  final authRefresh = ValueNotifier<int>(0);
  ref
    ..onDispose(authRefresh.dispose)
    ..listen(authStateNotifierProvider, (_, __) {
      authRefresh.value++;
    });
  if (_callAutotestEnabled) {
    _pendingCallAutotestInitialRoute = rememberCallAutotestInitialRoute(
      previousRoute: _pendingCallAutotestInitialRoute,
      consumedRoute: consumeCallAutotestInitialRouteFile(),
    );
  }

  return GoRouter(
    initialLocation: initialAppLocation(
      callAutotestEnabled: _callAutotestEnabled,
      environment: appRouterEnvironment(),
      arguments: appRouterExecutableArguments(),
      routeFileContent: _pendingCallAutotestInitialRoute,
    ),
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final authState = ref.read(authStateNotifierProvider);
      final auth = authState.valueOrNull;
      final redirect = authRedirectLocation(
        callAutotestEnabled: _callAutotestEnabled,
        isAuthLoading: authState.isLoading && authState.valueOrNull == null,
        isLoggedIn: auth?.isLoggedIn ?? false,
        requiresProfileSetup: auth?.requiresProfileSetup ?? false,
        matchedLocation: state.matchedLocation,
        uri: state.uri,
      );
      if (redirect != null) {
        debugPrint(
          '[router] redirect ${state.matchedLocation} -> $redirect '
          'loading=${authState.isLoading && auth == null} '
          'logged_in=${auth?.isLoggedIn ?? false} '
          'requires_profile_setup=${auth?.requiresProfileSetup ?? false} '
          'user=${auth?.userId ?? "<none>"}',
        );
      }
      return redirect;
    },
    routes: [
      GoRoute(path: '/restore', builder: (_, __) => const _AuthRestorePage()),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/init', builder: (_, __) => const InitPage()),
      GoRoute(
        path: '/setup/scan',
        pageBuilder: (_, __) => _slidePage(const SetupScanPage()),
      ),
      GoRoute(
        path: '/setup/password',
        pageBuilder: (_, state) {
          final payload = state.extra;
          if (payload is! SetupPayload) {
            return _slidePage(const LoginPage());
          }
          return _slidePage(OnboardingPasswordPage(payload: payload));
        },
      ),
      GoRoute(
        path: '/home',
        builder: (_, state) => HomePage(
          initialTab:
              _homeInitialTabFromQuery(state.uri.queryParameters['tab']),
        ),
      ),
      GoRoute(
        path: '/chat/:roomId',
        pageBuilder: (_, state) => _pageForLocation(
          state.matchedLocation,
          ChatPage(
            roomId: state.pathParameters['roomId']!,
            targetEventId: state.uri.queryParameters['event'],
          ),
        ),
      ),
      GoRoute(
        path: '/chat-info/:roomId',
        pageBuilder: (_, state) =>
            _slidePage(ChatInfoPage(roomId: state.pathParameters['roomId']!)),
      ),
      GoRoute(
        path: '/room-search/:roomId',
        pageBuilder: (_, state) => _slidePage(
          RoomSearchPage(roomId: state.pathParameters['roomId']!),
        ),
      ),
      GoRoute(
        path: '/group-info/:roomId',
        pageBuilder: (_, state) =>
            _slidePage(GroupInfoPage(roomId: state.pathParameters['roomId']!)),
      ),
      GoRoute(
        path: '/group/:roomId',
        pageBuilder: (_, state) => _pageForLocation(
          state.matchedLocation,
          GroupChatPage(
            roomId: state.pathParameters['roomId']!,
            targetEventId: state.uri.queryParameters['event'],
          ),
        ),
      ),
      GoRoute(
        path: '/contact/:userId',
        pageBuilder: (_, state) => _slidePage(
          ContactDetailPage(
            userId: state.pathParameters['userId']!,
            fromChatAvatar:
                state.uri.queryParameters['source'] == 'chat_avatar',
            fromChatInfo: state.uri.queryParameters['source'] == 'chat_info',
          ),
        ),
      ),
      GoRoute(
        path: '/contact-home/:userId',
        pageBuilder: (_, state) => _slidePage(
          ContactHomePage(userId: state.pathParameters['userId']!),
        ),
      ),
      GoRoute(
        path: '/contact-channels/:userId',
        pageBuilder: (_, state) => _slidePage(
          ContactChannelsPage(userId: state.pathParameters['userId']!),
        ),
      ),
      GoRoute(
        path: '/add-contact',
        pageBuilder: (_, __) => _slidePage(const AddContactPage()),
      ),
      GoRoute(
        path: '/add-contact/detail/:userId',
        pageBuilder: (_, state) => _slidePage(
          AddContactDetailPage(
            userId: state.pathParameters['userId']!,
            displayName: state.uri.queryParameters['name'],
            avatarUrl: state.uri.queryParameters['avatar'],
          ),
        ),
      ),
      GoRoute(
        path: '/add-contact/verify/:userId',
        pageBuilder: (_, state) => _slidePage(
          AddContactVerificationPage(
            userId: state.pathParameters['userId']!,
            displayName: state.uri.queryParameters['name'],
          ),
        ),
      ),
      GoRoute(
        path: '/requests',
        pageBuilder: (_, __) => _slidePage(const RequestsPage()),
      ),
      GoRoute(
        path: '/scan',
        pageBuilder: (_, __) => _slidePage(const QrScannerPage()),
      ),
      GoRoute(
        path: '/group-detail/:roomId',
        pageBuilder: (_, state) => _slidePage(
          GroupDetailPage(roomId: state.pathParameters['roomId']!),
        ),
      ),
      GoRoute(
        path: '/group-manage/:roomId',
        pageBuilder: (_, state) => _slidePage(
          GroupManagePage(roomId: state.pathParameters['roomId']!),
        ),
      ),
      GoRoute(
        path: '/groups',
        pageBuilder: (_, __) => _slidePage(const GroupsListPage()),
      ),
      GoRoute(
        path: '/follows',
        pageBuilder: (_, __) => _slidePage(const FollowsListPage()),
      ),
      GoRoute(
        path: '/me/account',
        pageBuilder: (_, __) => _slidePage(const MeAccountPage()),
      ),
      GoRoute(
        path: '/me/account/password',
        pageBuilder: (_, __) => _slidePage(const ChangePortalTokenPage()),
      ),
      GoRoute(
        path: '/me/notifications',
        pageBuilder: (_, __) => _slidePage(const MeNotificationsPage()),
      ),
      GoRoute(
        path: '/me/menu',
        pageBuilder: (_, __) => _slidePage(const MeMenuPage()),
      ),
      GoRoute(
        path: '/me/channels',
        pageBuilder: (_, __) => _slidePage(const MeChannelsPage()),
      ),
      GoRoute(
        path: '/me/favorites',
        pageBuilder: (_, __) => _slidePage(const MeFavoritesPage()),
      ),
      GoRoute(
        path: '/me/likes',
        pageBuilder: (_, __) => _slidePage(const MeLikesPage()),
      ),
      GoRoute(
        path: '/me/comments',
        pageBuilder: (_, __) => _slidePage(const MeCommentsPage()),
      ),
      GoRoute(
        path: '/me/drafts',
        pageBuilder: (_, __) => _slidePage(const MeDraftsPage()),
      ),
      GoRoute(
        path: '/me/history',
        pageBuilder: (_, __) => _slidePage(const MeHistoryPage()),
      ),
      GoRoute(
        path: '/me/wallet',
        pageBuilder: (_, __) => _slidePage(const MeWalletPage()),
      ),
      GoRoute(
        path: '/me/profile',
        pageBuilder: (_, __) => _slidePage(const ProfileInfoPage()),
      ),
      GoRoute(
        path: '/call/:roomId',
        pageBuilder: (_, state) => _slidePage(
          CallPage(
            roomId: state.pathParameters['roomId']!,
            callId: state.uri.queryParameters['call_id'],
            peerUserId: state.uri.queryParameters['peer'],
            peerDisplayName: state.uri.queryParameters['name'],
            peerAvatarUrl: state.uri.queryParameters['avatar'],
            incoming: state.uri.queryParameters['incoming'] == '1',
          ),
        ),
      ),
      GoRoute(
        path: '/video-call/:roomId',
        pageBuilder: (_, state) => _slidePage(
          CallPage(
            roomId: state.pathParameters['roomId']!,
            isVideo: true,
            callId: state.uri.queryParameters['call_id'],
            peerUserId: state.uri.queryParameters['peer'],
            peerDisplayName: state.uri.queryParameters['name'],
            peerAvatarUrl: state.uri.queryParameters['avatar'],
            incoming: state.uri.queryParameters['incoming'] == '1',
          ),
        ),
      ),
      GoRoute(
        path: '/group-call-invite/:roomId',
        pageBuilder: (_, state) => _slidePage(
          GroupCallMemberSelectPage(
            roomId: state.pathParameters['roomId']!,
            roomName: state.uri.queryParameters['name'],
            callType: groupCallTypeFromQuery(state.uri.queryParameters['type']),
          ),
        ),
      ),
      GoRoute(
        path: '/group-call/:roomId',
        pageBuilder: (_, state) => _slidePage(
          GroupCallPage(
            roomId: state.pathParameters['roomId']!,
            roomName: state.uri.queryParameters['name'],
            callId: state.uri.queryParameters['call_id'],
            inviteeIds: groupCallInviteesFromQuery(
              state.uri.queryParameters['invitees'],
            ),
            incoming: state.uri.queryParameters['incoming'] == '1',
            autoAnswer: state.uri.queryParameters['auto'] == '1',
          ),
        ),
      ),
      GoRoute(
        path: '/group-video-call/:roomId',
        pageBuilder: (_, state) => _slidePage(
          GroupCallPage(
            roomId: state.pathParameters['roomId']!,
            roomName: state.uri.queryParameters['name'],
            callId: state.uri.queryParameters['call_id'],
            inviteeIds: groupCallInviteesFromQuery(
              state.uri.queryParameters['invitees'],
            ),
            isVideo: true,
            incoming: state.uri.queryParameters['incoming'] == '1',
            autoAnswer: state.uri.queryParameters['auto'] == '1',
          ),
        ),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (_, __) => _slidePage(const SettingsPage()),
      ),
      GoRoute(
        path: '/settings/about',
        pageBuilder: (_, __) => _slidePage(const AboutUsPage()),
      ),
      GoRoute(
        path: '/settings/blacklist',
        pageBuilder: (_, __) => _slidePage(const BlacklistPage()),
      ),
      GoRoute(
        path: '/me/qr',
        pageBuilder: (_, __) => _slidePage(const MeQrPage()),
      ),
      GoRoute(
        path: '/search',
        pageBuilder: (_, __) => _slidePage(const SearchPage()),
      ),
      GoRoute(
        path: '/channels/search',
        pageBuilder: (_, __) => _slidePage(const ChannelSearchPage()),
      ),
      GoRoute(
        path: '/channels/review',
        pageBuilder: (_, __) => _slidePage(const ChannelReviewPage()),
      ),
      GoRoute(
        path: '/channels/manage',
        pageBuilder: (_, state) => _slidePage(
          ChannelManagementPage(
            initialSection: ChannelManagementSection.fromName(
              state.uri.queryParameters['tab'],
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/channels/manage/:channelId',
        pageBuilder: (_, state) => _slidePage(
          ChannelManagementPage(
            channelId: state.pathParameters['channelId'],
            initialSection: ChannelManagementSection.fromName(
              state.uri.queryParameters['tab'],
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/channel/:channelId/post/create',
        pageBuilder: (_, state) => _slidePage(
          ChannelPostCreatePage(channelId: state.pathParameters['channelId']!),
        ),
      ),
      GoRoute(
        path: '/channel/:channelId/post/:postId',
        pageBuilder: (_, state) => _slidePage(
          ChannelPostDetailPage(
            channelId: state.pathParameters['channelId']!,
            postId: state.pathParameters['postId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/channel/:channelId/info',
        pageBuilder: (_, state) => _slidePage(
          ChannelInfoPage(channelId: state.pathParameters['channelId']!),
        ),
      ),
      GoRoute(
        path: '/channel/:channelId/detail',
        pageBuilder: (_, state) => _slidePage(
          ChannelDetailInfoPage(
            channelId: state.pathParameters['channelId']!,
            sharePayload: state.extra is ChannelSharePayload
                ? state.extra! as ChannelSharePayload
                : null,
            showJoinButton: state.extra is ChannelSharePayload,
          ),
        ),
      ),
      GoRoute(
        path: '/channel/:channelId/conversation',
        pageBuilder: (_, state) {
          final channelId = state.pathParameters['channelId']!;
          final roomId = _channelConversationRoomId(
            ref,
            channelId,
          );
          return _pageForLocation(
            '/group/${Uri.encodeComponent(roomId)}',
            GroupChatPage(
              roomId: roomId,
              channelId: channelId,
              channelName: state.uri.queryParameters['name'],
            ),
          );
        },
      ),
      GoRoute(
        path: '/channel/:channelId',
        pageBuilder: (_, state) => _slidePage(
          ChannelPage(channelId: state.pathParameters['channelId']!),
        ),
      ),
      GoRoute(
        path: '/mcp-permission',
        pageBuilder: (_, __) => _slidePage(const McpPermissionPage()),
      ),
      GoRoute(
        path: '/mcp-permission/:agentId',
        pageBuilder: (_, state) => _slidePage(
          McpPolicyEditPage(agentId: state.pathParameters['agentId']!),
        ),
      ),
    ],
  );
}

class _AuthRestorePage extends StatefulWidget {
  const _AuthRestorePage();

  @override
  State<_AuthRestorePage> createState() => _AuthRestorePageState();
}

class _AuthRestorePageState extends State<_AuthRestorePage> {
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Scaffold(
      backgroundColor: t.bg,
      body: const SizedBox.expand(),
    );
  }
}
