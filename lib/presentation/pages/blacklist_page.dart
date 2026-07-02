import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../../l10n/app_localizations.dart';
import '../providers/as_bootstrap_store_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/block_list_provider.dart';
import '../providers/product_conversations_provider.dart';
import '../widgets/portal_avatar.dart';
import '../widgets/center_toast.dart';

class BlacklistPage extends ConsumerStatefulWidget {
  const BlacklistPage({super.key});

  @override
  ConsumerState<BlacklistPage> createState() => _BlacklistPageState();
}

class _BlacklistPageState extends ConsumerState<BlacklistPage> {
  final Set<String> _removing = {};

  Future<void> _refresh() async {
    await ref.read(blockListProvider.notifier).refresh();
  }

  Future<void> _remove(AsBlockItem entry) async {
    final key = '${entry.targetType}:${entry.displayId}';
    if (_removing.contains(key)) return;
    setState(() => _removing.add(key));
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    try {
      await ref.read(blockListProvider.notifier).removeBlock(
            targetType: entry.targetType,
            targetId: entry.displayId,
          );
      await _refreshVisibleListsAfterUnblock();
      if (!mounted) return;
      showTopSnackBar(
        context,
        SnackBar(
          content: Text(
            l10n?.blacklistRemovedMessage(_entryTitle(entry)) ??
                '已取消拉黑 ${_entryTitle(entry)}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      showTopSnackBar(
        context,
        SnackBar(
          content: Text(
            l10n?.blacklistRemoveFailed('$error') ?? '取消拉黑失败: $error',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _removing.remove(key));
    }
  }

  Future<void> _refreshVisibleListsAfterUnblock() async {
    try {
      final bootstrap = await ref.read(asBootstrapRepositoryProvider).refresh();
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.copyWith(bootstrap: bootstrap),
          );
      ref.invalidate(productConversationsProvider);
    } catch (error) {
      debugPrint('refresh bootstrap after unblock failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final topInset = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: t.surfaceHover,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _BlacklistHeader(topInset: topInset),
            Expanded(
              child: Builder(
                builder: (context) {
                  final value = ref.watch(blockListProvider);
                  final blocks = value.valueOrNull ?? const AsBlockList();
                  final entries = blocks.contacts;
                  return Column(
                    children: [
                      Expanded(
                        child: value.isLoading && value.valueOrNull == null
                            ? const Center(child: CircularProgressIndicator())
                            : value.hasError
                                ? _BlacklistError(onRetry: _refresh)
                                : entries.isEmpty
                                    ? const _BlacklistEmpty()
                                    : RefreshIndicator(
                                        onRefresh: _refresh,
                                        child: ListView.builder(
                                          padding:
                                              const EdgeInsets.only(top: 1),
                                          itemCount: entries.length,
                                          itemBuilder: (context, index) {
                                            final entry = entries[index];
                                            final key =
                                                '${entry.targetType}:${entry.displayId}';
                                            return _BlacklistRow(
                                              entry: entry,
                                              removing: _removing.contains(key),
                                              onRemove: () => _remove(entry),
                                            );
                                          },
                                        ),
                                      ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _entryTitle(AsBlockItem entry) {
  final name = entry.displayName.trim();
  if (name.isNotEmpty) return name;
  return entry.displayId;
}

class _BlacklistHeader extends StatelessWidget {
  const _BlacklistHeader({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return SizedBox(
      height: topInset + 57,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, topInset + 4, 16, 0),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _HeaderGlassButton(
                icon: Symbols.arrow_back,
                onTap: () => context.pop(),
              ),
            ),
            Text(
              l10n?.settingsBlacklist ?? '通讯录黑名单',
              style: AppTheme.sans(
                size: 16,
                weight: FontWeight.w600,
                color: t.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderGlassButton extends StatelessWidget {
  const _HeaderGlassButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: t.text.withValues(alpha: 0.12),
            blurRadius: 36,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: t.surface.withValues(alpha: 0.65),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(icon, size: 24, color: t.text),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BlacklistRow extends StatelessWidget {
  const _BlacklistRow({
    required this.entry,
    required this.removing,
    required this.onRemove,
  });

  final AsBlockItem entry;
  final bool removing;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            PortalAvatar(
              seed: entry.displayId,
              size: 28,
              imageUrl: entry.avatarUrl.trim().isEmpty
                  ? null
                  : entry.avatarUrl.trim(),
              shape: AvatarShape.squircle,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 52,
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: t.border.withValues(alpha: 0.45),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Text(
                  _entryTitle(entry),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(
                    size: 14,
                    weight: FontWeight.w500,
                    color: t.text,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _RemoveButton(
              busy: removing,
              onTap: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({
    required this.busy,
    required this.onTap,
  });

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return Material(
      color: t.text,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: busy ? null : onTap,
        child: SizedBox(
          height: 28,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                busy ? '处理中...' : l10n?.blacklistRemove ?? '取消拉黑',
                style: AppTheme.sans(
                  size: 12,
                  weight: FontWeight.w500,
                  color: t.surface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BlacklistEmpty extends StatelessWidget {
  const _BlacklistEmpty();

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return Center(
      child: Text(
        l10n?.blacklistContactsEmpty ?? l10n?.blacklistEmpty ?? '暂无拉黑好友',
        style: AppTheme.sans(size: 14, color: t.textMute),
      ),
    );
  }
}

class _BlacklistError extends StatelessWidget {
  const _BlacklistError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return Center(
      child: TextButton(
        onPressed: onRetry,
        child: Text(l10n?.commonRetry ?? '重试'),
      ),
    );
  }
}
