import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../providers/personal_space_provider.dart';
import '../widgets/m3/glass_header.dart';

class DynamicDetailPage extends ConsumerWidget {
  const DynamicDetailPage({super.key, required this.dynamicId});

  final String dynamicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = ref.watch(personalSpaceProvider).valueOrNull;
    final item = _findDynamic(space?.works ?? const <WorkItem>[], dynamicId);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          GlassHeader.detail(
            title: '动态详情',
            actions: [
              GlassHeaderButton(
                icon: Symbols.more_horiz,
                onTap: () => _showDynamicMenu(context),
              ),
            ],
          ),
          Expanded(
            child: item == null
                ? const _DynamicMissingState()
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                    child: _DynamicDetailBody(item: item),
                  ),
          ),
          if (item != null) const _DynamicActionBar(),
        ],
      ),
    );
  }
}

WorkItem? _findDynamic(List<WorkItem> items, String id) {
  for (final item in items) {
    if (item.id == id) return item;
  }
  return null;
}

void _showDynamicMenu(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Symbols.edit),
            title: const Text('编辑动态'),
            onTap: () => Navigator.of(ctx).pop(),
          ),
          ListTile(
            leading: const Icon(Symbols.delete),
            title: const Text('删除动态'),
            onTap: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    ),
  );
}

class _DynamicDetailBody extends StatelessWidget {
  const _DynamicDetailBody({required this.item});

  final WorkItem item;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              item.day.isEmpty ? item.month : '${item.month} ${item.day}',
              style: AppTheme.sans(size: 13, color: t.textMute),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: t.surfaceHover,
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Text(
                item.kind,
                style: AppTheme.sans(size: 11, color: t.textMute),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          item.title,
          style: AppTheme.sans(
            size: 24,
            weight: FontWeight.w700,
            color: t.text,
          ).copyWith(height: 1.2),
        ),
        const SizedBox(height: 16),
        _DynamicHeroPreview(item: item),
        const SizedBox(height: 18),
        Text(
          item.body,
          style: AppTheme.sans(size: 16, color: t.text).copyWith(height: 1.55),
        ),
      ],
    );
  }
}

class _DynamicHeroPreview extends StatelessWidget {
  const _DynamicHeroPreview({required this.item});

  final WorkItem item;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Color(item.previewColor),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Symbols.image, size: 38, color: t.textMute),
          const SizedBox(height: 8),
          Text(item.kind, style: AppTheme.sans(size: 13, color: t.textMute)),
        ],
      ),
    );
  }
}

class _DynamicActionBar extends StatelessWidget {
  const _DynamicActionBar();

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: t.surface,
          border:
              Border(top: BorderSide(color: t.border.withValues(alpha: 0.5))),
        ),
        child: const Row(
          children: [
            Expanded(
              child:
                  _DynamicActionButton(icon: Symbols.chat_bubble, label: '评论'),
            ),
            Expanded(
              child: _DynamicActionButton(icon: Symbols.ios_share, label: '转发'),
            ),
            Expanded(
              child:
                  _DynamicActionButton(icon: Symbols.more_horiz, label: '更多'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DynamicActionButton extends StatelessWidget {
  const _DynamicActionButton({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 42,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: t.textMute),
            const SizedBox(width: 5),
            Text(label, style: AppTheme.sans(size: 14, color: t.text)),
          ],
        ),
      ),
    );
  }
}

class _DynamicMissingState extends StatelessWidget {
  const _DynamicMissingState();

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Symbols.search_off, size: 36, color: t.textMute),
          const SizedBox(height: 12),
          Text(
            '动态不存在',
            style: AppTheme.sans(
              size: 15,
              weight: FontWeight.w600,
              color: t.text,
            ),
          ),
          const SizedBox(height: 4),
          Text('这条动态可能已删除或尚未同步',
              style: AppTheme.sans(size: 12, color: t.textMute)),
        ],
      ),
    );
  }
}
