import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../mock/mock_data.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/conversation_preferences_provider.dart';
import '../utils/group_creation_flow.dart';
import '../utils/message_preview.dart';
import '../widgets/m3/m3_search_field.dart';

const _groupsToolbarHeight = 62.0;

const _mockAuthEnabled = bool.fromEnvironment(
  'P2P_MATRIX_MOCK_AUTH',
  defaultValue: false,
);

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
    final useMockGroups = _mockAuthEnabled || !isLoggedIn;
    final syncCache = ref.watch(asSyncCacheProvider);
    final groupRemarkNames = ref.watch(groupRemarkNamesProvider);
    final directContactRoomIds = syncCache.acceptedContacts
        .map((contact) => contact.roomId.trim())
        .where((roomId) => roomId.isNotEmpty)
        .toSet();

    final items = <_GroupItem>[];
    if (!useMockGroups) {
      final groups = [...?syncCache.bootstrap?.groups]..sort((a, b) {
          final ta = a.lastActivityAt?.millisecondsSinceEpoch ?? 0;
          final tb = b.lastActivityAt?.millisecondsSinceEpoch ?? 0;
          return tb.compareTo(ta);
        });
      for (final group in groups) {
        final roomId = group.roomId.trim();
        if (roomId.isEmpty) continue;
        if (directContactRoomIds.contains(roomId)) continue;
        final room = client.getRoomById(roomId);
        final lastEvent = room?.lastEvent;
        final lastActivityAt =
            lastEvent?.originServerTs ?? group.lastActivityAt;
        items.add(
          _GroupItem(
            id: roomId,
            name: (groupRemarkNames[roomId]?.trim().isNotEmpty ?? false)
                ? groupRemarkNames[roomId]!.trim()
                : group.name.trim().isNotEmpty
                    ? group.name.trim()
                    : room?.getLocalizedDisplayname() ?? '群聊',
            preview: lastEvent == null
                ? _previewText(group.topic)
                : roomEventPreviewText(lastEvent, isAgent: false),
            time: lastActivityAt == null
                ? ''
                : _formatTime(lastActivityAt.millisecondsSinceEpoch),
            unread: group.unreadCount > 0
                ? group.unreadCount
                : room?.notificationCount ?? 0,
            isOwner: group.isOwned,
          ),
        );
      }
    } else {
      final mocks = MockData.groupConversations;
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
            isOwner: c.isOwnerGroup,
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
          _GroupsToolbar(
            title: '群聊',
            onBack: () => Navigator.of(context).maybePop(),
            onCreate: () => showCreateGroupFlow(context, ref),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: filtered.length,
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
    return M3SearchField(hint: '搜索群聊', onChanged: onChanged);
  }
}

class _GroupsToolbar extends StatelessWidget {
  const _GroupsToolbar({
    required this.title,
    required this.onBack,
    required this.onCreate,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: _groupsToolbarHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _GroupsHeaderButton(
                  icon: Symbols.arrow_back,
                  onTap: onBack,
                ),
              ),
              Text(
                title,
                style: AppTheme.sans(
                  size: 16,
                  weight: FontWeight.w600,
                  color: t.text,
                ).copyWith(letterSpacing: 0),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: _GroupsHeaderButton(
                  icon: Symbols.group_add,
                  color: t.accent,
                  onTap: onCreate,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupsHeaderButton extends StatelessWidget {
  const _GroupsHeaderButton({
    required this.icon,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: t.text.withValues(alpha: 0.08),
            blurRadius: 36,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipOval(
        child: Material(
          color: t.surface.withValues(alpha: 0.72),
          child: InkWell(
            onTap: onTap,
            child: SizedBox.square(
              dimension: 40,
              child: Icon(icon, size: 24, color: color ?? t.text),
            ),
          ),
        ),
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
    this.isOwner = false,
  });
  final String id;
  final String name;
  final String preview;
  final String time;
  final int unread;
  final bool isOwner;
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
      color: t.surface.withValues(alpha: 0),
      child: InkWell(
        onTap: () {
          final path = item.id.startsWith('mock_') ? '/chat' : '/group';
          context.push('$path/${Uri.encodeComponent(item.id)}');
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _GroupAvatar(name: name),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: preview.isEmpty ? 56 : 64,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: t.border.withValues(alpha: 0.45),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                      color: t.text,
                                    ),
                                  ),
                                ),
                                if (item.isOwner) ...[
                                  const SizedBox(width: 6),
                                  _OwnerBadge(),
                                ],
                              ],
                            ),
                            if (preview.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                preview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.sans(
                                  size: 12,
                                  color: t.textMute,
                                ),
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
                              style: AppTheme.sans(
                                size: 12,
                                color: unread > 0 ? t.accent : t.textMute,
                              ),
                            ),
                          if (unread > 0) ...[
                            const SizedBox(height: 4),
                            Container(
                              height: 20,
                              constraints: const BoxConstraints(minWidth: 20),
                              padding: EdgeInsets.symmetric(
                                horizontal: unread > 99 ? 5 : 0,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: t.accent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                unread > 99 ? '99+' : '$unread',
                                textAlign: TextAlign.center,
                                style: AppTheme.sans(
                                  size: unread > 99 ? 9 : 11,
                                  weight: FontWeight.w700,
                                  color: t.onAccent,
                                ).copyWith(height: 1),
                              ),
                            ),
                          ],
                        ],
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

class _OwnerBadge extends StatelessWidget {
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
        '群主',
        style: AppTheme.sans(
          size: 10,
          weight: FontWeight.w600,
          color: t.textMute,
        ),
      ),
    );
  }
}

/// 群聊头像：48 圆角方块，按群名 hash 取色，显示 groups 图标。
class _GroupAvatar extends StatelessWidget {
  const _GroupAvatar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final colors = [t.accent, t.primaryContainer, t.accentCool, t.danger];
    final bg = colors[name.hashCode.abs() % colors.length];
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
  if (diffDays < 7) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekdays[dt.weekday - 1];
  }
  return DateFormat('MM/dd').format(dt);
}
