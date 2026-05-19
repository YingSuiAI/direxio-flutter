import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../presentation/pages/login_page.dart';
import '../../presentation/pages/init_page.dart';
import '../../presentation/pages/home_page.dart';
import '../../presentation/pages/chat_page.dart';
import '../../presentation/pages/chat_info_page.dart';
import '../../presentation/pages/group_info_page.dart';
import '../../presentation/pages/group_chat_page.dart';
import '../../presentation/pages/contact_detail_page.dart';
import '../../presentation/pages/add_contact_page.dart';
import '../../presentation/pages/requests_page.dart';
import '../../presentation/pages/group_detail_page.dart';
import '../../presentation/pages/group_manage_page.dart';
import '../../presentation/pages/groups_list_page.dart';
import '../../presentation/pages/me_account_page.dart';
import '../../presentation/pages/me_notifications_page.dart';
import '../../presentation/pages/call_page.dart';
import '../../presentation/pages/settings_page.dart';
import '../../presentation/pages/search_page.dart';
import '../../presentation/pages/mcp_permission_page.dart';
import '../../presentation/pages/mcp_policy_edit_page.dart';
import '../../presentation/providers/auth_provider.dart';

part 'app_router.g.dart';

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

@riverpod
GoRouter appRouter(Ref ref) {
  final authState = ref.watch(authStateNotifierProvider);

  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      // MOCK: skip auth, go straight to home
      if (state.matchedLocation == '/login' ||
          state.matchedLocation == '/init') {
        return '/home';
      }
      return null;
      // ignore: dead_code
      final isLoggedIn = authState.valueOrNull?.isLoggedIn ?? false;
      final isLoginRoute =
          state.matchedLocation == '/login' || state.matchedLocation == '/init';

      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/init', builder: (_, __) => const InitPage()),
      GoRoute(path: '/home', builder: (_, __) => const HomePage()),
      GoRoute(
        path: '/chat/:roomId',
        pageBuilder: (_, state) =>
            _slidePage(ChatPage(roomId: state.pathParameters['roomId']!)),
      ),
      GoRoute(
        path: '/chat-info/:roomId',
        pageBuilder: (_, state) =>
            _slidePage(ChatInfoPage(roomId: state.pathParameters['roomId']!)),
      ),
      GoRoute(
        path: '/group-info/:roomId',
        pageBuilder: (_, state) =>
            _slidePage(GroupInfoPage(roomId: state.pathParameters['roomId']!)),
      ),
      GoRoute(
        path: '/group/:roomId',
        pageBuilder: (_, state) =>
            _slidePage(GroupChatPage(roomId: state.pathParameters['roomId']!)),
      ),
      GoRoute(
        path: '/contact/:userId',
        pageBuilder: (_, state) => _slidePage(
          ContactDetailPage(userId: state.pathParameters['userId']!),
        ),
      ),
      GoRoute(
        path: '/add-contact',
        pageBuilder: (_, __) => _slidePage(const AddContactPage()),
      ),
      GoRoute(
        path: '/requests',
        pageBuilder: (_, __) => _slidePage(const RequestsPage()),
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
        path: '/me/account',
        pageBuilder: (_, __) => _slidePage(const MeAccountPage()),
      ),
      GoRoute(
        path: '/me/notifications',
        pageBuilder: (_, __) => _slidePage(const MeNotificationsPage()),
      ),
      GoRoute(
        path: '/call/:roomId',
        pageBuilder: (_, state) =>
            _slidePage(CallPage(roomId: state.pathParameters['roomId']!)),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (_, __) => _slidePage(const SettingsPage()),
      ),
      GoRoute(
        path: '/search',
        pageBuilder: (_, __) => _slidePage(const SearchPage()),
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
