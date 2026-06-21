import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../providers/as_client_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/glass_list_tile.dart';
import '../widgets/m3/glass_header.dart';
import '../widgets/portal_avatar.dart';

final _followsProvider = FutureProvider.autoDispose<List<FollowEntry>>((ref) {
  final isLoggedIn =
      ref.watch(authStateNotifierProvider).valueOrNull?.isLoggedIn ?? false;
  if (!isLoggedIn) return Future.value(const <FollowEntry>[]);
  return ref.watch(asClientProvider).getFollows();
});

class FollowsListPage extends ConsumerWidget {
  const FollowsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final follows = ref.watch(_followsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          GlassHeader.detail(title: '关注'),
          Expanded(
            child: follows.when(
              data: (items) => _FollowsList(items: items),
              loading: () => Center(
                child: CircularProgressIndicator(color: t.accent),
              ),
              error: (error, _) => _FollowsStateMessage(
                icon: Symbols.error,
                title: '关注列表加载失败',
                detail: error.toString(),
                actionLabel: '重试',
                onAction: () => ref.invalidate(_followsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowsList extends StatelessWidget {
  const _FollowsList({required this.items});

  final List<FollowEntry> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _FollowsStateMessage(
        icon: Symbols.person_check,
        title: '还没有关注',
        detail: '关注其他用户后，会在这里集中查看。',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
      itemCount: items.length,
      itemBuilder: (_, index) => _FollowTile(item: items[index]),
    );
  }
}

class _FollowTile extends StatelessWidget {
  const _FollowTile({required this.item});

  final FollowEntry item;

  @override
  Widget build(BuildContext context) {
    final homeUserId = _homeUserIdForFollow(item);
    return GlassListTile(
      onTap: () => context.push(
        '/contact-home/${Uri.encodeComponent(homeUserId)}',
      ),
      leading: PortalAvatar(
        seed: item.domain,
        size: 48,
      ),
      title: item.name.isEmpty ? item.domain : item.name,
      subtitle: item.followedAt == null
          ? item.domain
          : '${item.domain} · 关注于 ${_formatFollowDate(item.followedAt!)}',
    );
  }
}

String _homeUserIdForFollow(FollowEntry item) {
  if (item.domain.startsWith('@') && item.domain.contains(':')) {
    return item.domain;
  }
  final domain = item.domain
      .trim()
      .replaceAll(RegExp(r'^https?://', caseSensitive: false), '')
      .replaceAll(RegExp(r'/+$'), '');
  return '@owner:$domain';
}

String _formatFollowDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$month-$day';
}

class _FollowsStateMessage extends StatelessWidget {
  const _FollowsStateMessage({
    required this.icon,
    required this.title,
    required this.detail,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: t.textMute),
            const SizedBox(height: 10),
            Text(
              title,
              style: AppTheme.sans(
                size: 16,
                weight: FontWeight.w600,
                color: t.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: AppTheme.sans(size: 13, color: t.textMute)
                  .copyWith(height: 1.35),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
