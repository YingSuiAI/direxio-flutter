import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../mock/mock_data.dart';
import '../providers/auth_provider.dart';
import '../widgets/m3/glass_header.dart';

/// `s-groups-list` — 群聊列表 (index.html L1566-1643)
///
/// 通讯录 → 群聊 入口。展示所有群聊房间，点击进入群聊。
class GroupsListPage extends ConsumerStatefulWidget {
  const GroupsListPage({super.key});

  @override
  ConsumerState<GroupsListPage> createState() => _GroupsListPageState();
}

class _GroupsListPageState extends ConsumerState<GroupsListPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final client = ref.watch(matrixClientProvider);
    final isLoggedIn =
        ref.watch(authStateNotifierProvider).valueOrNull?.isLoggedIn ?? false;

    final items = <_GroupItem>[];
    if (isLoggedIn) {
      final groups = client.rooms.where((r) => !r.isDirectChat).toList()
        ..sort((a, b) {
          final ta = a.lastEvent?.originServerTs.millisecondsSinceEpoch ?? 0;
          final tb = b.lastEvent?.originServerTs.millisecondsSinceEpoch ?? 0;
          return tb.compareTo(ta);
        });
      for (final r in groups) {
        items.add(
          _GroupItem(
            id: r.id,
            name: r.getLocalizedDisplayname(),
            preview: _previewText(r.lastEvent?.body ?? ''),
            time: r.lastEvent == null
                ? ''
                : _formatTime(
                    r.lastEvent!.originServerTs.millisecondsSinceEpoch,
                  ),
            unread: r.notificationCount,
          ),
        );
      }
    } else {
      // Mock 模式：把 mxid 不以 @ 起头的会话视为群组。
      final mocks = MockData.conversations
          .where((c) => !c.mxid.startsWith('@'))
          .toList();
      for (final c in mocks) {
        final last = c.lastMessage;
        items.add(
          _GroupItem(
            id: c.id,
            name: c.name,
            preview: _previewText(last?.text ?? ''),
            time: last == null
                ? ''
                : _formatTime(last.time.millisecondsSinceEpoch),
            unread: c.unread,
          ),
        );
      }
    }

    final filtered = _query.isEmpty
        ? items
        : items
              .where((g) => g.name.toLowerCase().contains(_query.toLowerCase()))
              .toList();

    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          GlassHeader.detail(
            title: '群聊',
            actions: [
              GlassHeaderButton(
                icon: Symbols.group_add,
                color: t.accent,
                onTap: () => context.push('/add-contact'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _SearchBar(onChanged: (v) => setState(() => _query = v)),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      _query.isEmpty ? '还没有群聊' : '没有匹配的群聊',
                      style: AppTheme.sans(size: 13, color: t.textMute),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => Padding(
                      padding: const EdgeInsets.only(left: 76),
                      child: Container(
                        height: 1,
                        color: t.border.withValues(alpha: 0.2),
                      ),
                    ),
                    itemBuilder: (_, i) => _GroupRow(item: filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: t.surfaceHover,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Symbols.search, size: 18, color: t.textMute),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              cursorColor: t.accent,
              style: AppTheme.sans(size: 15, color: t.text),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: '搜索群聊',
                hintStyle: AppTheme.sans(size: 15, color: t.textMute),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupItem {
  const _GroupItem({
    required this.id,
    required this.name,
    required this.preview,
    required this.time,
    required this.unread,
  });
  final String id;
  final String name;
  final String preview;
  final String time;
  final int unread;
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.item});
  final _GroupItem item;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final name = item.name;
    final preview = item.preview;
    final time = item.time;
    final unread = item.unread;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final path = item.id.startsWith('mock_') ? '/chat' : '/group';
          context.push('$path/${Uri.encodeComponent(item.id)}');
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _GroupAvatar(name: name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.sans(
                        size: 17,
                        weight: FontWeight.w600,
                        color: t.text,
                      ),
                    ),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.sans(size: 13, color: t.textMute),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (time.isNotEmpty)
                    Text(
                      time,
                      style: AppTheme.sans(size: 11, color: t.textMute),
                    ),
                  if (unread > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: t.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        style: AppTheme.sans(
                          size: 11,
                          weight: FontWeight.w700,
                          color: t.onAccent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 群聊头像：48 圆角方块，按群名 hash 取色，显示 groups 图标。
class _GroupAvatar extends StatelessWidget {
  const _GroupAvatar({required this.name});
  final String name;

  // 与 group_detail_page 头像 strip 一致的色板。
  static const _palette = <Color>[
    Color(0xFF0058BC),
    Color(0xFFFF9500),
    Color(0xFFA8DAB5),
    Color(0xFF5856D6),
    Color(0xFF5AC8FA),
    Color(0xFFBA1A1A),
  ];

  @override
  Widget build(BuildContext context) {
    final i = name.hashCode.abs() % _palette.length;
    final bg = _palette[i];
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(Symbols.groups, size: 24, color: bg, fill: 1),
    );
  }
}

String _previewText(String raw) {
  return raw
      .replaceAll(RegExp(r'[*_`#~]'), '')
      .replaceAll(RegExp(r'\s*\n+\s*'), ' ')
      .trim();
}

String _formatTime(int ts) {
  final dt = DateTime.fromMillisecondsSinceEpoch(ts);
  final now = DateTime.now();
  final diffDays = now.difference(dt).inDays;
  if (diffDays == 0) return DateFormat('HH:mm').format(dt);
  if (diffDays == 1) return '昨天';
  if (diffDays < 7) return DateFormat('EEE', 'zh').format(dt);
  return DateFormat('MM/dd').format(dt);
}
