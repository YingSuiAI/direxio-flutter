import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/product_conversations_provider.dart';
import '../utils/product_conversation_navigation.dart';

String? _channelConversationRoomId(WidgetRef ref, String rawChannelId) {
  final channelId = rawChannelId.trim();
  if (channelId.isEmpty) return null;
  final channels =
      ref.read(asSyncCacheProvider).bootstrap?.channels ?? const [];
  for (final channel in channels) {
    final roomId = channel.roomId.trim();
    if (roomId.isEmpty) continue;
    if (channel.channelId.trim() == channelId || roomId == channelId) {
      return roomId;
    }
  }
  return null;
}

class ChannelConversationRoutePage extends ConsumerWidget {
  const ChannelConversationRoutePage({super.key, required this.channelId});

  final String channelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(productConversationsProvider);
    return conversationsAsync.when(
      data: (conversations) {
        final byRoomId = productConversationForRoom(
          conversations,
          channelId,
          kinds: const {asConversationKindChannel},
        );
        final resolvedRoomId = _channelConversationRoomId(ref, channelId);
        final conversation = byRoomId ??
            (resolvedRoomId == null
                ? null
                : productConversationForRoom(
                    conversations,
                    resolvedRoomId,
                    kinds: const {asConversationKindChannel},
                  ));
        if (conversation == null) {
          return const _RouteStatePage(message: '频道会话同步中，请稍后重试');
        }
        final route = productConversationRoute(conversation);
        if (route == null) {
          return const _RouteStatePage(message: '频道会话暂不可打开');
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.go(route);
        });
        return const _RouteStatePage(message: '正在打开频道会话');
      },
      loading: () => const _RouteStatePage(message: '正在同步频道会话'),
      error: (_, __) => const _RouteStatePage(message: '频道会话同步失败，请稍后重试'),
    );
  }
}

class _RouteStatePage extends StatelessWidget {
  const _RouteStatePage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tk.bg,
      body: Center(
        child: Text(
          message,
          style: AppTheme.sans(size: 15, color: context.tk.textMute),
        ),
      ),
    );
  }
}
