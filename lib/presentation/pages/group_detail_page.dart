import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../mock/mock_data.dart';
import '../groups/group_leave_flow.dart';
import '../groups/group_member_invite_flow.dart';
import '../providers/auth_provider.dart';
import '../utils/avatar_url.dart';
import '../widgets/portal_avatar.dart';
import '../widgets/m3/glass_header.dart';

/// GROUP INFO 屏 —— 1:1 复刻 P2P-APP-UI/index.html 中 #s-group-info（678-808 行）。
/// 保留 Riverpod / Matrix client 数据查询；widget 树严格对齐设计稿。
class GroupDetailPage extends ConsumerStatefulWidget {
  const GroupDetailPage({super.key, required this.roomId});
  final String roomId;

  @override
  ConsumerState<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends ConsumerState<GroupDetailPage> {
  bool _mute = false;
  bool _pinned = false;
  bool _showNicknames = true;
  bool _leaving = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final client = ref.read(matrixClientProvider);
    final room = client.getRoomById(widget.roomId);
    // 找不到真房间时回退 mock（产品设计组等以 mock_ 起头）。
    final mock = room == null ? MockData.byId(widget.roomId) : null;
    if (room == null && mock == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: Text('群组不存在')),
      );
    }

    final realMembers = room?.getParticipants() ?? const <User>[];
    final existingMemberMxids = realMembers
        .map((member) => member.id.trim())
        .where((mxid) => mxid.isNotEmpty)
        .toSet();
    final members = _buildMemberStripData(
      realMembers,
      client: client,
      padWithMocks: room == null,
    );
    final memberCount =
        realMembers.isEmpty ? members.length : realMembers.length;
    final canManageGroup = room == null || _canManageGroup(room);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          GlassHeader.detail(
            title: '聊天信息($memberCount)',
            actions: [
              GlassHeaderButton(
                icon: Symbols.search,
                color: t.accent,
                onTap: () => context.push(
                  '/room-search/${Uri.encodeComponent(widget.roomId)}',
                ),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MemberStrip(
                    members: members,
                    onInvite: () => showInviteGroupMembersFlow(
                      context,
                      ref,
                      roomId: widget.roomId,
                      existingMemberMxids: existingMemberMxids,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _GroupedCard(
                    children: [
                      _RowChevron(label: '群公告', onTap: () {}),
                      if (canManageGroup) ...[
                        _Divider(),
                        _RowChevron(
                          label: '群管理',
                          onTap: () => context.push(
                            '/group-manage/${Uri.encodeComponent(widget.roomId)}',
                          ),
                        ),
                      ],
                      _Divider(),
                      _RowChevron(label: '备注', onTap: () {}),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _GroupedCard(
                    children: [
                      _RowChevron(
                        label: '查找聊天记录',
                        onTap: () => context.push(
                          '/room-search/${Uri.encodeComponent(widget.roomId)}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _GroupedCard(
                    children: [
                      _RowSwitch(
                        label: '消息免打扰',
                        value: _mute,
                        onChanged: (v) => setState(() => _mute = v),
                      ),
                      _Divider(),
                      _RowSwitch(
                        label: '置顶聊天',
                        value: _pinned,
                        onChanged: (v) => setState(() => _pinned = v),
                      ),
                      _Divider(),
                      _RowChevron(
                        label: '我在群里的昵称',
                        trailingText: 'Alex',
                        onTap: () {},
                      ),
                      _Divider(),
                      _RowSwitch(
                        label: '显示群成员昵称',
                        value: _showNicknames,
                        onChanged: (v) => setState(() => _showNicknames = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _GroupedCard(
                    children: [
                      _RowChevron(label: '设置当前聊天背景', onTap: () {}),
                      _Divider(),
                      _RowChevron(label: '清空聊天记录', onTap: () {}),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _GroupedCard(
                    children: [
                      _RowDanger(
                        label: '退出群聊',
                        onTap: () => _confirmLeave(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 设计稿写死 6 个 ABCDEF。如果真实成员可用，就用真实名字配设计稿的色板。
  List<_Member> _buildMemberStripData(
    List<User> real, {
    required Client client,
    required bool padWithMocks,
  }) {
    final palette = <Color>[
      context.tk.accent, // A —— primary
      const Color(0xFFFF9500), // B
      const Color(0xFFA8DAB5), // C —— tertiary-container 近似
      const Color(0xFF5856D6), // D
      const Color(0xFF5AC8FA), // E
      context.tk.danger, // F —— error
    ];
    const onColors = <Color>[
      Color(0xFFFFFFFF), // on-primary
      Color(0xFFFFFFFF),
      Color(0xFF0E2010),
      Color(0xFFFFFFFF),
      Color(0xFFFFFFFF),
      Color(0xFFFFFFFF),
    ];
    const mockNames = ['Alice', 'Bob', 'Carol', 'Dave', 'Eve', 'Frank'];

    final out = <_Member>[];
    final count = padWithMocks ? 6 : real.length;
    for (var i = 0; i < count; i++) {
      final name = i < real.length
          ? (real[i].displayName ?? real[i].id.replaceFirst('@', ''))
          : mockNames[i];
      out.add(
        _Member(
          initial: name.characters.first.toUpperCase(),
          name: name,
          avatarUrl: i < real.length
              ? matrixContentHttpUrl(client, real[i].avatarUrl)
              : null,
          bg: palette[i],
          fg: onColors[i],
        ),
      );
    }
    return out;
  }

  bool _canManageGroup(Room room) {
    final self = room.client.userID;
    if (self == null || self.isEmpty) return false;
    return room.getPowerLevelByUserId(self) >= 50;
  }

  Future<void> _confirmLeave(BuildContext context) async {
    if (_leaving) return;
    final t = context.tk;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          '退出群聊',
          style: AppTheme.sans(size: 17, weight: FontWeight.w600),
        ),
        content: Text(
          '退出后你将不再接收该群聊消息。',
          style: AppTheme.sans(size: 15, color: t.textMute),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(
              '取消',
              style: AppTheme.sans(size: 15, color: t.textMute),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(
              '退出',
              style: AppTheme.sans(
                size: 15,
                weight: FontWeight.w600,
                color: t.danger,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _leaving = true);
    try {
      await leaveGroupThroughAs(ref, widget.roomId);
      if (!context.mounted) return;
      context.go('/home');
    } on Object catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('退出群聊失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
  }
}

// ─────────────────────────── 成员头像 strip ───────────────────────────

class _Member {
  const _Member({
    required this.initial,
    required this.name,
    this.avatarUrl,
    required this.bg,
    required this.fg,
  });
  final String initial;
  final String name;
  final String? avatarUrl;
  final Color bg;
  final Color fg;
}

class _MemberStrip extends StatelessWidget {
  const _MemberStrip({required this.members, required this.onInvite});
  final List<_Member> members;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border.withValues(alpha: 0.3)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            for (var i = 0; i < members.length; i++) ...[
              _MemberTile(member: members[i]),
              if (i != members.length - 1) const SizedBox(width: 12),
            ],
            const SizedBox(width: 12),
            _InviteTile(onTap: onInvite),
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member});
  final _Member member;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PortalAvatar(
          seed: member.name.isNotEmpty ? member.name : member.initial,
          size: 48,
          imageUrl: member.avatarUrl,
        ),
        const SizedBox(height: 4),
        Text(
          member.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.sans(size: 10, color: t.textMute),
        ),
      ],
    );
  }
}

class _InviteTile extends StatelessWidget {
  const _InviteTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DottedCircle(
              size: 48,
              color: t.border,
              child: Icon(Symbols.add, size: 20, color: t.border),
            ),
            const SizedBox(height: 4),
            Text('邀请', style: AppTheme.sans(size: 10, color: t.textMute)),
          ],
        ),
      ),
    );
  }
}

/// 虚线圆圈 —— 用 CustomPaint 模拟 border-dashed border-2 rounded-full。
class DottedCircle extends StatelessWidget {
  const DottedCircle({
    super.key,
    required this.size,
    required this.color,
    required this.child,
  });
  final double size;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedCirclePainter(color: color),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(child: child),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  _DashedCirclePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final radius = size.shortestSide / 2 - 1;
    final center = size.center(Offset.zero);
    const dashCount = 24;
    const sweep = 6.2831853 / dashCount;
    for (var i = 0; i < dashCount; i++) {
      final start = i * sweep;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep * 0.55,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter old) => old.color != color;
}

// ─────────────────────────── 分组卡片 / 行 ───────────────────────────

class _GroupedCard extends StatelessWidget {
  const _GroupedCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.border.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: context.tk.border.withValues(alpha: 0.2),
    );
  }
}

class _RowChevron extends StatelessWidget {
  const _RowChevron({
    required this.label,
    this.trailingText,
    required this.onTap,
  });
  final String label;
  final String? trailingText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTheme.sans(size: 17, color: t.text),
                ),
              ),
              if (trailingText != null) ...[
                Text(
                  trailingText!,
                  style: AppTheme.sans(size: 15, color: t.textMute),
                ),
                const SizedBox(width: 4),
              ],
              Icon(Symbols.chevron_right, size: 22, color: t.border),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowSwitch extends StatelessWidget {
  const _RowSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppTheme.sans(size: 17, color: t.text)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: t.accent,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: t.secondaryContainer,
          ),
        ],
      ),
    );
  }
}

class _RowDanger extends StatelessWidget {
  const _RowDanger({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Center(
            child: Text(
              label,
              style: AppTheme.sans(
                size: 17,
                weight: FontWeight.w500,
                color: t.danger,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
