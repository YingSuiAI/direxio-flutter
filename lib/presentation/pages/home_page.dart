import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../widgets/portal_avatar.dart';
import '../mock/mock_data.dart';
import '../mock/mcp_policy.dart';
import '../mock/mcp_audit.dart';
import '../../data/as_client.dart';
import '../../data/mock_as_client.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';

/// Portal 整体状态 —— 对应 INTERFACE_SPEC.md §5.5。
/// autoDispose + 30s 内复用，避免每次 rebuild 都打 AS API。
final portalStatusProvider = FutureProvider.autoDispose<PortalStatus>((ref) {
  ref.keepAlive();
  return ref.read(asClientProvider).getPortalStatus();
});

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _tab = 0;
  StreamSubscription<SyncUpdate>? _syncSub;

  @override
  void initState() {
    super.initState();
    // 订阅 client.onSync,任何 /sync 周期触发就重建,
    // 让会话列表的 lastEvent / notificationCount / 新房间 实时更新。
    final client = ref.read(matrixClientProvider);
    _syncSub = client.onSync.stream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(matrixClientProvider);
    final t = context.tk;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: t.accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: t.accent.withValues(alpha: 0.4)),
              ),
              alignment: Alignment.center,
              child: Icon(LucideIcons.message_square,
                  size: 12, color: t.accent),
            ),
            const SizedBox(width: 8),
            Text('Portal IM',
                style:
                    AppTheme.mono(size: 15, weight: FontWeight.w700, color: t.text)),
            const SizedBox(width: 8),
            const _PortalStatusChip(),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.search, size: 18, color: t.text),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: Icon(LucideIcons.settings, size: 18, color: t.text),
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: LayoutBuilder(
        builder: (ctx, c) {
          final wide = c.maxWidth >= 900;
          final pane = switch (_tab) {
            0 => _ChatList(client: client),
            1 => _ContactList(client: client),
            2 => _AgentTabBody(),
            _ => _MePage(client: client),
          };
          if (!wide) return pane;
          // 宽屏：左侧栏 + master pane，详情区放占位/欢迎卡
          return Row(
            children: [
              SizedBox(width: 340, child: pane),
              VerticalDivider(width: 1, color: t.border),
              Expanded(child: _DetailPlaceholder()),
            ],
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.message_square, size: 18),
            selectedIcon: Icon(LucideIcons.message_square, size: 18),
            label: '消息',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.users, size: 18),
            selectedIcon: Icon(LucideIcons.users, size: 18),
            label: '联系人',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.bot, size: 18),
            selectedIcon: Icon(LucideIcons.bot, size: 18),
            label: 'Agent',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.user, size: 18),
            selectedIcon: Icon(LucideIcons.user, size: 18),
            label: '我',
          ),
        ],
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton(
              onPressed: () => context.push('/add-contact'),
              child: const Icon(LucideIcons.plus, size: 22),
            )
          : null,
    );
  }
}

class _ChatList extends ConsumerWidget {
  const _ChatList({required this.client});
  final Client client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = client.rooms;
    final t = context.tk;
    final isLoggedIn =
        ref.watch(authStateNotifierProvider).valueOrNull?.isLoggedIn ?? false;

    // 未登录时展示 mock 会话用于演示；已登录则始终走真数据，
    // rooms 为空也显示真实空态，不回退 mock。
    if (!isLoggedIn) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
        itemCount: MockData.conversations.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final c = MockData.conversations[i];
          return _MockChatTile(conv: c, t: t);
        },
      );
    }

    if (rooms.isEmpty) {
      return const _Empty(
        icon: LucideIcons.message_square_dashed,
        title: '还没有会话',
        subtitle: '去添加联系人开始聊天',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      itemCount: rooms.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final room = rooms[i];
        return _ChatTile(room: room, t: t);
      },
    );
  }
}

class _MockChatTile extends StatelessWidget {
  const _MockChatTile({required this.conv, required this.t});
  final MockConversation conv;
  final PortalTokens t;

  @override
  Widget build(BuildContext context) {
    final last = conv.lastMessage;
    final time = last == null
        ? ''
        : DateFormat('HH:mm').format(last.time);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push('/chat/${conv.id}'),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: t.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PortalAvatar(seed: conv.name, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(conv.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.sans(
                                  size: 15,
                                  weight: FontWeight.w600,
                                  color: t.text)),
                        ),
                        Text(time,
                            style: AppTheme.mono(size: 11, color: t.textMute)),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(conv.mxid,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              AppTheme.mono(size: 11, color: t.accentCool)),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            last?.text ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                AppTheme.sans(size: 13, color: t.textMute),
                          ),
                        ),
                        if (conv.unread > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: t.accent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('${conv.unread}',
                                style: AppTheme.mono(
                                    size: 10,
                                    color: Colors.black,
                                    weight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.room, required this.t});
  final Room room;
  final PortalTokens t;

  @override
  Widget build(BuildContext context) {
    final isDm = room.isDirectChat;
    final name = room.getLocalizedDisplayname();
    final lastEvent = room.lastEvent;
    final mxid = room.directChatMatrixID ?? '';
    final unread = room.notificationCount;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => isDm
            ? context.push('/chat/${Uri.encodeComponent(room.id)}')
            : context.push('/group/${Uri.encodeComponent(room.id)}'),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: t.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PortalAvatar(seed: name, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.sans(
                                  size: 15,
                                  weight: FontWeight.w600,
                                  color: t.text)),
                        ),
                        if (lastEvent != null)
                          Text(
                              _formatTime(
                                  lastEvent.originServerTs.millisecondsSinceEpoch),
                              style: AppTheme.mono(
                                  size: 11, color: t.textMute)),
                      ],
                    ),
                    if (isDm && mxid.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(mxid,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.mono(
                                size: 11, color: t.accentCool)),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastEvent?.body ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.sans(
                                size: 13, color: t.textMute),
                          ),
                        ),
                        if (unread > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: t.accent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('$unread',
                                style: AppTheme.mono(
                                    size: 10,
                                    color: Colors.black,
                                    weight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final now = DateTime.now();
    if (now.difference(dt).inDays == 0) return DateFormat('HH:mm').format(dt);
    if (now.difference(dt).inDays == 1) return '昨天';
    if (now.difference(dt).inDays < 7) return DateFormat('EEE', 'zh').format(dt);
    return DateFormat('MM/dd').format(dt);
  }
}

Future<void> _showCreateGroupDialog(
    BuildContext context, Client client) async {
  final nameCtrl = TextEditingController();
  final inviteCtrl = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('创建群组'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: '群名称'),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: inviteCtrl,
            decoration: const InputDecoration(
              labelText: '邀请成员（可选）',
              hintText: '@owner:example.com，多个用逗号分隔',
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

  final invites = inviteCtrl.text
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.startsWith('@'))
      .toList();

  try {
    final roomId = await client.createRoom(
      name: name,
      invite: invites,
      preset: CreateRoomPreset.privateChat,
      isDirect: false,
    );
    if (context.mounted) context.push('/group/${Uri.encodeComponent(roomId)}');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('创建失败: $e')));
    }
  }
}

class _ContactList extends ConsumerWidget {
  const _ContactList({required this.client});
  final Client client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final dmRooms = client.rooms.where((r) => r.isDirectChat).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        _ActionTile(
          icon: LucideIcons.user_plus,
          label: '添加联系人',
          subtitle: '通过域名',
          onTap: () => context.push('/add-contact'),
        ),
        const SizedBox(height: 8),
        _ActionTile(
          icon: LucideIcons.users,
          label: '创建群组',
          subtitle: '邀请联系人',
          onTap: () => _showCreateGroupDialog(context, client),
        ),
        const SizedBox(height: 8),
        _ActionTile(
          icon: LucideIcons.bell_dot,
          label: '好友/群邀请',
          subtitle: 'Pending',
          onTap: () => context.push('/requests'),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '联系人 (${dmRooms.length})',
            style: AppTheme.mono(
                size: 11,
                color: t.textMute,
                weight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        ...dmRooms.map((room) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ChatTile(room: room, t: t),
            )),
      ],
    );
  }
}

class _MePage extends ConsumerWidget {
  const _MePage({required this.client});
  final Client client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final userId = client.userID ?? '';
    final domain = userId.contains(':') ? userId.split(':').last : userId;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: t.border),
          ),
          child: Column(
            children: [
              PortalAvatar(seed: domain, size: 64),
              const SizedBox(height: 12),
              FutureBuilder<Profile?>(
                future: client.userID != null
                    ? client.getProfileFromUserId(client.userID!)
                    : Future.value(null),
                builder: (_, snap) => Text(
                  snap.data?.displayName ?? '未设置昵称',
                  style: AppTheme.sans(
                      size: 18, weight: FontWeight.w600, color: t.text),
                ),
              ),
              const SizedBox(height: 4),
              PortalMxid(userId, size: 12),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ActionTile(
          icon: LucideIcons.settings,
          label: '设置',
          onTap: () => context.push('/settings'),
        ),
        const SizedBox(height: 8),
        _ActionTile(
          icon: LucideIcons.log_out,
          label: '退出登录',
          danger: true,
          onTap: () async {
            await ref.read(authStateNotifierProvider.notifier).logout();
          },
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final color = danger ? t.danger : t.text;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: t.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: AppTheme.sans(
                        size: 14, weight: FontWeight.w500, color: color)),
              ),
              if (subtitle != null) ...[
                Text(subtitle!,
                    style: AppTheme.mono(size: 11, color: t.textMute)),
                const SizedBox(width: 6),
              ],
              Icon(LucideIcons.chevron_right, size: 16, color: t.textMute),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, required this.subtitle});
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
          Text(title,
              style: AppTheme.sans(
                  size: 14, color: t.text, weight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(subtitle, style: AppTheme.sans(size: 12, color: t.textMute)),
        ],
      ),
    );
  }
}

class _AgentTabBody extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final policies = ref.watch(mcpPolicyStoreProvider);
    final audit = ref.watch(mcpAuditStoreProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: t.border),
          ),
          child: Row(children: [
            Icon(LucideIcons.bot, size: 20, color: t.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Agent 中心',
                      style: AppTheme.sans(
                          size: 15,
                          weight: FontWeight.w600,
                          color: t.text)),
                  const SizedBox(height: 4),
                  Text(
                      '已授权 ${policies.values.where((p) => p.enabled).length} / ${policies.length} · 今日活动 ${audit.length} 次',
                      style:
                          AppTheme.sans(size: 12, color: t.textMute)),
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        _SectionHead('我的 Agent'),
        ...policies.values.map((p) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _AgentCard(p: p),
            )),
        const SizedBox(height: 16),
        _SectionHead('最近活动'),
        if (audit.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text('暂无活动',
                style:
                    AppTheme.sans(size: 12, color: t.textMute)),
          )
        else
          ...audit.take(5).map((e) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: t.border),
                  ),
                  child: Row(children: [
                    Icon(
                      e.outcome == McpAuditOutcome.denied
                          ? LucideIcons.circle_x
                          : LucideIcons.circle_check,
                      size: 12,
                      color: e.outcome == McpAuditOutcome.denied
                          ? t.danger
                          : t.accent,
                    ),
                    const SizedBox(width: 8),
                    Text(e.tool,
                        style: AppTheme.mono(
                            size: 12,
                            color: t.text,
                            weight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          e.deniedReason ?? e.resultSummary ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.sans(
                              size: 11, color: t.textMute)),
                    ),
                    Text(DateFormat('HH:mm').format(e.ts),
                        style: AppTheme.mono(
                            size: 10, color: t.textMute)),
                  ]),
                ),
              )),
      ],
    );
  }
}

class _SectionHead extends StatelessWidget {
  const _SectionHead(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 6),
      child: Text(text.toUpperCase(),
          style: AppTheme.mono(
              size: 11,
              color: context.tk.textMute,
              weight: FontWeight.w600)),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({required this.p});
  final McpPolicy p;
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push('/chat/mock_aibot'),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: t.border),
          ),
          child: Row(children: [
            PortalAvatar(seed: p.mxid, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(p.displayName,
                        style: AppTheme.sans(
                            size: 14,
                            weight: FontWeight.w600,
                            color: t.text)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: (p.enabled ? t.accent : t.textMute)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(p.enabled ? '已授权' : '已停用',
                          style: AppTheme.mono(
                              size: 9,
                              weight: FontWeight.w600,
                              color: p.enabled
                                  ? t.accent
                                  : t.textMute)),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Text(p.summary,
                      style:
                          AppTheme.sans(size: 11, color: t.textMute)),
                ],
              ),
            ),
            IconButton(
              icon: Icon(LucideIcons.settings_2,
                  size: 16, color: t.textMute),
              onPressed: () =>
                  context.push('/mcp-permission/${p.agentId}'),
            ),
          ]),
        ),
      ),
    );
  }
}

class _DetailPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      color: t.bg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.message_square_dashed,
                size: 48, color: t.textMute),
            const SizedBox(height: 14),
            Text('选择左侧的会话开始对话',
                style: AppTheme.sans(size: 14, color: t.textMute)),
            const SizedBox(height: 6),
            Text('或在 Agent 标签里与 AI Bot 协作',
                style: AppTheme.sans(size: 12, color: t.textMute)),
          ],
        ),
      ),
    );
  }
}

/// AppBar 上的 Portal 状态指示。三态：在线 / 异常 / 离线 / 连接中。
class _PortalStatusChip extends ConsumerWidget {
  const _PortalStatusChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final async = ref.watch(portalStatusProvider);

    final (Color color, String label) = switch (async) {
      AsyncData(:final value) when value.allHealthy => (t.accent, '在线'),
      AsyncData() => (Colors.amber, '异常'),
      AsyncError() => (t.danger, '离线'),
      _ => (t.textMute, '连接中'),
    };

    return Tooltip(
      message: switch (async) {
        AsyncData(:final value) =>
          'Dendrite: ${value.dendrite}\nFederation: ${value.federation}\n'
              'Agent: ${value.agent}\nUptime: ${value.uptime}',
        AsyncError() => 'Portal 不可达',
        _ => '正在查询 Portal 状态',
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(label, style: AppTheme.mono(size: 10, color: color)),
          ],
        ),
      ),
    );
  }
}
