import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
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
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../providers/as_client_provider.dart';
import '../widgets/m3/glass_header.dart';
import '../widgets/m3/m3_bottom_nav.dart';

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

  static const _tabTitles = ['Agent', '消息', '通讯录', '我'];

  List<Widget> _headerActions(BuildContext context, Client client) {
    switch (_tab) {
      case 0:
        return [
          GlassHeaderButton(
            icon: Symbols.settings,
            color: context.tk.accent,
            onTap: () => context.push('/mcp-permission'),
          ),
        ];
      case 1:
        return [
          GlassHeaderButton(
            icon: Symbols.search,
            onTap: () => context.push('/search'),
          ),
          _HomePlusMenuButton(client: client),
        ];
      case 2:
        return [
          GlassHeaderButton(
            icon: Symbols.person_add,
            color: context.tk.accent,
            onTap: () => context.push('/add-contact'),
          ),
        ];
      default:
        return [
          GlassHeaderButton(
            icon: Symbols.settings,
            color: context.tk.accent,
            onTap: () => context.push('/settings'),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(matrixClientProvider);
    final t = context.tk;

    return Scaffold(
      body: Column(
        children: [
          GlassHeader.primary(
            leading: _tab == 1
                ? GestureDetector(
                    onTap: () => setState(() => _tab = 3),
                    child: const PortalAvatar(
                      seed: 'me',
                      size: 32,
                      imageUrl: MockAvatars.me,
                    ),
                  )
                : null,
            title: _tabTitles[_tab],
            titleColor: _tab == 1 ? t.accent : t.text,
            actions: _headerActions(context, client),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, c) {
                final wide = c.maxWidth >= 900;
                final pane = switch (_tab) {
                  0 => _AgentTabBody(),
                  1 => _ChatList(client: client),
                  2 => _ContactList(client: client),
                  _ => _MePage(client: client),
                };
                if (!wide) return pane;
                return Row(
                  children: [
                    SizedBox(width: 340, child: pane),
                    VerticalDivider(width: 1, color: t.border),
                    Expanded(child: _DetailPlaceholder()),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: M3BottomNav(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          M3NavItem(
            icon: Symbols.robot_2,
            activeIcon: Symbols.robot_2,
            label: 'Agent',
          ),
          M3NavItem(
            icon: Symbols.chat_bubble,
            activeIcon: Symbols.chat_bubble,
            label: '消息',
          ),
          M3NavItem(
            icon: Symbols.contacts,
            activeIcon: Symbols.contacts,
            label: '通讯录',
          ),
          M3NavItem(
            icon: Symbols.person,
            activeIcon: Symbols.person,
            label: '我',
          ),
        ],
      ),
    );
  }
}

enum _PlusAction { group, contact, scan, file }

class _HomePlusMenuButton extends StatelessWidget {
  const _HomePlusMenuButton({required this.client});
  final Client client;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return PopupMenuButton<_PlusAction>(
      tooltip: '更多',
      color: const Color(0xFF1E2026), // theme-fixed: 原型 + 菜单恒为深色弹层
      elevation: 12,
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (action) {
        switch (action) {
          case _PlusAction.group:
            _showCreateGroupDialog(context, client);
          case _PlusAction.contact:
            context.push('/add-contact');
          case _PlusAction.scan:
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('扫一扫功能待接入')));
          case _PlusAction.file:
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('文件传输功能待接入')));
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _PlusAction.group,
          child: _PlusMenuItem(icon: Symbols.group_add, label: '发起群聊'),
        ),
        PopupMenuItem(
          value: _PlusAction.contact,
          child: _PlusMenuItem(icon: Symbols.person_add, label: '添加朋友'),
        ),
        PopupMenuItem(
          value: _PlusAction.scan,
          child: _PlusMenuItem(icon: Symbols.qr_code_scanner, label: '扫一扫'),
        ),
        PopupMenuItem(
          value: _PlusAction.file,
          child: _PlusMenuItem(icon: Symbols.file_present, label: '文件传输'),
        ),
      ],
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(Symbols.add, size: 22, color: t.textMute),
      ),
    );
  }
}

class _PlusMenuItem extends StatelessWidget {
  const _PlusMenuItem({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.82)),
        const SizedBox(width: 12),
        Text(label, style: AppTheme.sans(size: 14, color: Colors.white)),
      ],
    );
  }
}

class _ChatList extends ConsumerWidget {
  const _ChatList({required this.client});
  final Client client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = client.rooms;
    final isLoggedIn =
        ref.watch(authStateNotifierProvider).valueOrNull?.isLoggedIn ?? false;

    // 未登录时展示 mock 会话用于演示；已登录则始终走真数据，
    // rooms 为空也显示真实空态，不回退 mock。
    if (!isLoggedIn) {
      final convs = MockData.conversations;
      return ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 96),
        itemCount: convs.length,
        itemBuilder: (context, i) {
          final c = convs[i];
          final last = c.lastMessage;
          return _ConvRow(
            name: c.name,
            lastMessage: _previewText(last?.text ?? ''),
            time: last == null ? '' : DateFormat('HH:mm').format(last.time),
            unread: c.unread,
            isAgent: c.id == 'mock_aibot',
            isGroup: c.isGroup,
            avatarUrl: c.avatarUrl,
            online: !c.isGroup && c.id != 'mock_aibot',
            isLast: i == convs.length - 1,
            onTap: () => context.push('/chat/${c.id}'),
          );
        },
      );
    }

    if (rooms.isEmpty) {
      return const _Empty(
        icon: Symbols.forum,
        title: '还没有会话',
        subtitle: '去添加联系人开始聊天',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 96),
      itemCount: rooms.length,
      itemBuilder: (context, i) {
        final room = rooms[i];
        final isDm = room.isDirectChat;
        final lastEvent = room.lastEvent;
        return _ConvRow(
          name: room.getLocalizedDisplayname(),
          lastMessage: _previewText(lastEvent?.body ?? ''),
          time: lastEvent == null
              ? ''
              : _formatConvTime(
                  lastEvent.originServerTs.millisecondsSinceEpoch,
                ),
          unread: room.notificationCount,
          isLast: i == rooms.length - 1,
          onTap: () => isDm
              ? context.push('/chat/${Uri.encodeComponent(room.id)}')
              : context.push('/group/${Uri.encodeComponent(room.id)}'),
        );
      },
    );
  }
}

String _formatConvTime(int ts) {
  final dt = DateTime.fromMillisecondsSinceEpoch(ts);
  final now = DateTime.now();
  if (now.difference(dt).inDays == 0) return DateFormat('HH:mm').format(dt);
  if (now.difference(dt).inDays == 1) return '昨天';
  if (now.difference(dt).inDays < 7) return DateFormat('EEE', 'zh').format(dt);
  return DateFormat('MM/dd').format(dt);
}

/// 会话列表"最后一条消息"预览：去掉 Markdown 标记 + 折行，保留纯文本。
String _previewText(String raw) {
  return raw
      .replaceAll(RegExp(r'[*_`#~]'), '')
      .replaceAll(RegExp(r'\s*\n+\s*'), ' ')
      .trim();
}

/// 会话列表行 —— 对齐设计稿 s-messages chat-list item。
/// 列表式（贴边、底分隔线、整行 ripple），头像 48 圆形。
class _ConvRow extends StatelessWidget {
  const _ConvRow({
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unread,
    required this.onTap,
    this.isAgent = false,
    this.isGroup = false,
    this.avatarUrl,
    this.online = false,
    this.isLast = false,
  });
  final String name;
  final String lastMessage;
  final String time;
  final int unread;
  final VoidCallback onTap;
  final bool isAgent;
  final bool isGroup;
  final String? avatarUrl;
  final bool online;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    Offset rcPos = Offset.zero;
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        // 桌面端右键 / 移动端长按 → 弹 chat-ctx-menu（置顶/不显示/删除聊天）。
        onSecondaryTapDown: (d) => rcPos = d.globalPosition,
        onSecondaryTap: () => _showChatCtxMenu(context, rcPos, name),
        onLongPressStart: (d) {
          rcPos = d.globalPosition;
          _showChatCtxMenu(context, rcPos, name);
        },
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Row(
              children: [
                // 头像 48 + 在线点
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(
                    children: [
                      if (isAgent)
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: t.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Symbols.robot_2,
                            size: 24,
                            color: t.onPrimaryContainer,
                            fill: 1,
                          ),
                        )
                      else if (isGroup)
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: t.surfaceHigh,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Symbols.groups,
                            size: 24,
                            color: t.textMute,
                            fill: 1,
                          ),
                        )
                      else
                        PortalAvatar(seed: name, size: 48, imageUrl: avatarUrl),
                      if (online)
                        const Positioned(
                          bottom: 0,
                          right: 0,
                          child: OnlineDot(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // 内容区 + 底分隔线
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(top: 6, bottom: 12),
                    decoration: isLast
                        ? null
                        : BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: t.surfaceHigh),
                            ),
                          ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.sans(
                                  size: 20,
                                  weight: FontWeight.w600,
                                  color: t.text,
                                ),
                              ),
                            ),
                            if (isAgent) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: t.primaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'AI',
                                  style: AppTheme.sans(
                                    size: 11,
                                    weight: FontWeight.w700,
                                    color: t.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            Text(
                              time,
                              style: AppTheme.sans(
                                size: 13,
                                color: unread > 0 ? t.accent : t.textMute,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.sans(
                                  size: 15,
                                  color: t.textMute,
                                ),
                              ),
                            ),
                            if (unread > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: t.accent,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '$unread',
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _showChatCtxMenu(BuildContext context, Offset pos, String name) {
  final size = MediaQuery.of(context).size;
  const menuW = 176.0;
  const menuH = 148.0;
  var left = pos.dx;
  var top = pos.dy;
  if (left + menuW > size.width - 8) left = size.width - menuW - 8;
  if (top + menuH > size.height - 8) top = size.height - menuH - 8;
  if (left < 8) left = 8;
  if (top < 8) top = 8;

  showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'chat-ctx',
    barrierColor: Colors.black.withValues(alpha: 0.15),
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (ctx, _, __) => Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: menuW,
          child: _ChatCtxMenuCard(name: name),
        ),
      ],
    ),
    transitionBuilder: (ctx, a, _, child) =>
        FadeTransition(opacity: a, child: child),
  );
}

class _ChatCtxMenuCard extends StatelessWidget {
  const _ChatCtxMenuCard({required this.name});
  final String name;

  // chat-ctx-menu 用固定深色，与 light/dark 主题无关（对齐 index.html#chat-ctx-menu）。
  static const _dark = Color(0xFF1E2026);
  static const _divider = Color(0x1AFFFFFF);
  static const _icon = Color(0xB3FFFFFF);
  static const _label = Colors.white;
  static const _danger = Color(0xFFFF6B6B);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: _dark,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _row(context, Symbols.push_pin, '置顶', () {
              Navigator.of(context).pop();
              _toast(context, '已置顶「$name」');
            }),
            const Divider(
              height: 1,
              color: _divider,
              indent: 16,
              endIndent: 16,
            ),
            _row(context, Symbols.visibility_off, '不显示', () {
              Navigator.of(context).pop();
              _toast(context, '已隐藏「$name」');
            }),
            const Divider(
              height: 1,
              color: _divider,
              indent: 16,
              endIndent: 16,
            ),
            _row(context, Symbols.delete, '删除聊天', () {
              Navigator.of(context).pop();
              _toast(context, '已删除「$name」');
            }, danger: true),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext ctx,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool danger = false,
  }) {
    final color = danger ? _danger : _label;
    final iconColor = danger ? _danger : _icon;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 12),
            Text(label, style: AppTheme.sans(size: 15, color: color)),
          ],
        ),
      ),
    );
  }

  void _toast(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );
  }
}

Future<void> _showCreateGroupDialog(BuildContext context, Client client) async {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('创建失败: $e')));
    }
  }
}

class _ContactList extends ConsumerWidget {
  const _ContactList({required this.client});
  final Client client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final isLoggedIn =
        ref.watch(authStateNotifierProvider).valueOrNull?.isLoggedIn ?? false;
    final dmRooms = client.rooms.where((r) => r.isDirectChat).toList();
    // 通讯录里只放"个人联系人"。Mock 数据里群组（mxid 以 # / ! 起头）和 AI bot
    // 排除——群组归「群聊」入口管。
    final mockContacts = MockData.conversations
        .where((c) => c.id != 'mock_aibot' && c.mxid.startsWith('@'))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
      children: [
        HomeSearchBox(hint: '搜索', onTap: () => context.push('/search')),
        const SizedBox(height: 14),
        _ActionSection(
          children: [
            _SectionAction(
              icon: Symbols.person_add,
              label: '新朋友',
              badge: '2',
              iconColor: t.accent,
              onTap: () => context.push('/requests'),
            ),
            _SectionAction(
              icon: Symbols.group,
              label: '群聊',
              iconColor: t.accentCool,
              onTap: () => context.push('/groups'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '联系人 (${isLoggedIn ? dmRooms.length : mockContacts.length})',
            style: AppTheme.mono(
              size: 11,
              color: t.textMute,
              weight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (isLoggedIn)
          _ActionSection(
            children: dmRooms
                .map(
                  (room) => _ContactEntryTile(
                    name: room.getLocalizedDisplayname(),
                    subtitle: room.directChatMatrixID,
                    online: true,
                    onTap: () {
                      final mxid = room.directChatMatrixID;
                      if (mxid != null) {
                        context.push('/contact/${Uri.encodeComponent(mxid)}');
                      }
                    },
                  ),
                )
                .toList(),
          )
        else
          _ActionSection(
            children: mockContacts
                .map(
                  (c) => _ContactEntryTile(
                    name: c.name,
                    subtitle: c.mxid,
                    online: true,
                    avatarUrl: c.avatarUrl,
                    onTap: () =>
                        context.push('/contact/${Uri.encodeComponent(c.mxid)}'),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class HomeSearchBox extends StatelessWidget {
  const HomeSearchBox({super.key, required this.hint, required this.onTap});
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.surfaceHover,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(Symbols.search, size: 18, color: t.textMute),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hint,
                  style: AppTheme.sans(size: 14, color: t.textMute),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionSection extends StatelessWidget {
  const _ActionSection({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    if (children.isEmpty) {
      return const _Empty(
        icon: Symbols.person,
        title: '还没有联系人',
        subtitle: '添加联系人后会显示在这里',
      );
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(
                height: 1,
                indent: 52,
                color: t.border.withValues(alpha: 0.16),
              ),
          ],
        ],
      ),
    );
  }
}

class _SectionAction extends StatelessWidget {
  const _SectionAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.iconColor,
    this.iconBg,
    this.subtitle,
    this.badge,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;
  final Color? iconBg;
  final String? subtitle;
  final String? badge;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final textColor = danger ? t.danger : t.text;
    final bg = iconBg;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: bg ?? iconColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: bg == null ? t.onAccent : iconColor,
                fill: 1,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTheme.sans(
                  size: 16,
                  weight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            if (subtitle != null) ...[
              Text(
                subtitle!,
                style: AppTheme.sans(size: 13, color: t.textMute),
              ),
              const SizedBox(width: 8),
            ],
            if (badge != null) ...[
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.danger,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  badge!,
                  style: AppTheme.sans(
                    size: 10,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(Symbols.chevron_right, size: 20, color: t.textMute),
          ],
        ),
      ),
    );
  }
}

class _ContactEntryTile extends StatelessWidget {
  const _ContactEntryTile({
    required this.name,
    required this.onTap,
    this.subtitle,
    this.online = false,
    this.avatarUrl,
  });

  final String name;
  final String? subtitle;
  final VoidCallback onTap;
  final bool online;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                children: [
                  PortalAvatar(seed: name, size: 40, imageUrl: avatarUrl),
                  if (online)
                    const Positioned(
                      right: 0,
                      bottom: 0,
                      child: OnlineDot(size: 10),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(
                      size: 16,
                      weight: FontWeight.w500,
                      color: t.text,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.sans(size: 12, color: t.textMute),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Symbols.chevron_right, size: 20, color: t.textMute),
          ],
        ),
      ),
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
    final displayId = userId.isEmpty ? '@me:portal.agent-p2p.io' : userId;
    final domain = displayId.contains(':')
        ? displayId.split(':').last
        : displayId;
    final shortId = displayId.length > 16
        ? '${displayId.substring(0, 6)}…${displayId.substring(displayId.length - 6)}'
        : displayId;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 96),
      children: [
        // Profile —— index.html s-me 头部
        Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: t.surfaceHover, width: 2),
                  ),
                  child: ClipOval(
                    child: PortalAvatar(
                      seed: domain,
                      size: 96,
                      imageUrl: MockAvatars.me,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: t.surfaceHigh,
                      shape: BoxShape.circle,
                      border: Border.all(color: t.bg, width: 2),
                    ),
                    child: Icon(
                      Symbols.photo_camera,
                      size: 16,
                      color: t.textMute,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<Profile?>(
              future: client.userID != null
                  ? client.getProfileFromUserId(client.userID!)
                  : Future.value(null),
              builder: (_, snap) => Text(
                snap.data?.displayName ?? 'Alex Chen',
                style: AppTheme.sans(
                  size: 20,
                  weight: FontWeight.w600,
                  color: t.text,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '@${domain.split(':').first}',
              style: AppTheme.sans(size: 15, color: t.textMute),
            ),
            const SizedBox(height: 8),
            Tooltip(
              message: displayId,
              child: GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: displayId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Node ID 已复制'), duration: Duration(seconds: 1)),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: t.surfaceHigh,
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(color: t.border.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: t.tertiaryFixed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Node: $shortId',
                        style: AppTheme.sans(size: 13, color: t.textMute),
                      ),
                      const SizedBox(width: 6),
                      Icon(Symbols.content_copy, size: 14, color: t.accent),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // 账号与安全
        _ActionSection(
          children: [
            _SectionAction(
              icon: Symbols.shield_person,
              label: '账号与安全',
              iconColor: t.accent,
              iconBg: t.accent.withValues(alpha: 0.1),
              onTap: () => context.push('/me/account'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 通知设置
        _ActionSection(
          children: [
            _SectionAction(
              icon: Symbols.notifications,
              label: '通知设置',
              iconColor: const Color(0xFFFF9500),
              iconBg: const Color(0xFFFF9500).withValues(alpha: 0.15),
              onTap: () => context.push('/me/notifications'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 通用
        _ActionSection(
          children: [
            _SectionAction(
              icon: Symbols.settings,
              label: '通用',
              iconColor: t.textMute,
              iconBg: t.surfaceHover,
              onTap: () => context.push('/settings'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 退出登录
        Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.border.withValues(alpha: 0.3)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('退出登录'),
                    content: const Text('确定要退出登录吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text('退出', style: TextStyle(color: context.tk.danger)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(authStateNotifierProvider.notifier).logout();
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Text(
                    '退出登录',
                    style: AppTheme.sans(
                      size: 17,
                      weight: FontWeight.w500,
                      color: t.danger,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
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
          Text(
            title,
            style: AppTheme.sans(
              size: 14,
              color: t.text,
              weight: FontWeight.w500,
            ),
          ),
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.border.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: t.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Symbols.smart_toy,
                  size: 24,
                  color: t.onPrimaryContainer,
                  fill: 1,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Agent 中心',
                      style: AppTheme.sans(
                        size: 17,
                        weight: FontWeight.w600,
                        color: t.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '已授权 ${policies.values.where((p) => p.enabled).length} / ${policies.length} · 今日活动 ${audit.length} 次',
                      style: AppTheme.sans(size: 12, color: t.textMute),
                    ),
                  ],
                ),
              ),
              const _PortalStatusChip(),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _ActionSection(
          children: [
            _SectionAction(
              icon: Symbols.smart_toy,
              label: '打开 AI Bot',
              subtitle: '聊天与工具调用',
              iconColor: t.accent,
              onTap: () => context.push('/chat/mock_aibot'),
            ),
            _SectionAction(
              icon: Symbols.admin_panel_settings,
              label: '权限管理',
              subtitle: 'MCP Policy',
              iconColor: t.accentCool,
              onTap: () => context.push('/mcp-permission'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _SectionHead('我的 Agent'),
        ...policies.values.map(
          (p) => Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _AgentCard(p: p),
          ),
        ),
        const SizedBox(height: 16),
        const _SectionHead('最近活动'),
        if (audit.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '暂无活动',
              style: AppTheme.sans(size: 12, color: t.textMute),
            ),
          )
        else
          ...audit
              .take(5)
              .map(
                (e) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: t.border.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          e.outcome == McpAuditOutcome.denied
                              ? Symbols.cancel
                              : Symbols.check_circle,
                          size: 12,
                          color: e.outcome == McpAuditOutcome.denied
                              ? t.danger
                              : t.accent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          e.tool,
                          style: AppTheme.mono(
                            size: 12,
                            color: t.text,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            e.deniedReason ?? e.resultSummary ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.sans(size: 11, color: t.textMute),
                          ),
                        ),
                        Text(
                          DateFormat('HH:mm').format(e.ts),
                          style: AppTheme.mono(size: 10, color: t.textMute),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
      child: Text(
        text.toUpperCase(),
        style: AppTheme.mono(
          size: 11,
          color: context.tk.textMute,
          weight: FontWeight.w600,
        ),
      ),
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
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/chat/mock_aibot'),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.border.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              PortalAvatar(seed: p.mxid, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          p.displayName,
                          style: AppTheme.sans(
                            size: 14,
                            weight: FontWeight.w600,
                            color: t.text,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: (p.enabled ? t.accent : t.textMute)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            p.enabled ? '已授权' : '已停用',
                            style: AppTheme.mono(
                              size: 9,
                              weight: FontWeight.w600,
                              color: p.enabled ? t.accent : t.textMute,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.summary,
                      style: AppTheme.sans(size: 11, color: t.textMute),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Symbols.tune, size: 16, color: t.textMute),
                onPressed: () => context.push('/mcp-permission/${p.agentId}'),
              ),
            ],
          ),
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
            Icon(Symbols.forum, size: 48, color: t.textMute),
            const SizedBox(height: 14),
            Text(
              '选择左侧的会话开始对话',
              style: AppTheme.sans(size: 14, color: t.textMute),
            ),
            const SizedBox(height: 6),
            Text(
              '或在 Agent 标签里与 AI Bot 协作',
              style: AppTheme.sans(size: 12, color: t.textMute),
            ),
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
