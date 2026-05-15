import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../presentation/pages/login_page.dart';
import '../../presentation/pages/init_page.dart';
import '../../presentation/pages/home_page.dart';
import '../../presentation/pages/chat_page.dart';
import '../../presentation/pages/group_chat_page.dart';
import '../../presentation/pages/contact_detail_page.dart';
import '../../presentation/pages/add_contact_page.dart';
import '../../presentation/pages/requests_page.dart';
import '../../presentation/pages/group_detail_page.dart';
import '../../presentation/pages/call_page.dart';
import '../../presentation/pages/settings_page.dart';
import '../../presentation/pages/search_page.dart';
import '../../presentation/pages/mcp_permission_page.dart';
import '../../presentation/pages/mcp_policy_edit_page.dart';
import '../../presentation/providers/auth_provider.dart';

part 'app_router.g.dart';

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
      final isLoginRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/init';

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
        builder: (_, state) => ChatPage(roomId: state.pathParameters['roomId']!),
      ),
      GoRoute(
        path: '/group/:roomId',
        builder: (_, state) => GroupChatPage(roomId: state.pathParameters['roomId']!),
      ),
      GoRoute(
        path: '/contact/:userId',
        builder: (_, state) => ContactDetailPage(userId: state.pathParameters['userId']!),
      ),
      GoRoute(path: '/add-contact', builder: (_, __) => const AddContactPage()),
      GoRoute(path: '/requests', builder: (_, __) => const RequestsPage()),
      GoRoute(
        path: '/group-detail/:roomId',
        builder: (_, state) => GroupDetailPage(roomId: state.pathParameters['roomId']!),
      ),
      GoRoute(
        path: '/call/:roomId',
        builder: (_, state) => CallPage(roomId: state.pathParameters['roomId']!),
      ),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
      GoRoute(path: '/search', builder: (_, __) => const SearchPage()),
      GoRoute(
          path: '/mcp-permission',
          builder: (_, __) => const McpPermissionPage()),
      GoRoute(
          path: '/mcp-permission/:agentId',
          builder: (_, state) =>
              McpPolicyEditPage(agentId: state.pathParameters['agentId']!)),
    ],
  );
}
