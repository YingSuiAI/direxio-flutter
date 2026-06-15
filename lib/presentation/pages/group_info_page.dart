/// 群「群信息」—— 对齐原型 s-group-info。M3 风格，真实 Matrix 数据。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../groups/group_leave_flow.dart';
import '../groups/group_member_invite_flow.dart';
import '../providers/auth_provider.dart';
import '../utils/avatar_url.dart';
import '../widgets/m3/glass_header.dart';
import '../widgets/m3/m3_card.dart';
import '../widgets/portal_avatar.dart';
import '../widgets/info_rows.dart';

class GroupInfoPage extends ConsumerStatefulWidget {
  const GroupInfoPage({super.key, required this.roomId});
  final String roomId;

  @override
  ConsumerState<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends ConsumerState<GroupInfoPage> {
  bool _mute = false;
  bool _pinned = false;
  bool _showMemberNick = true;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    final room = ref.read(matrixClientProvider).getRoomById(widget.roomId);
    if (room == null) return;
    try {
      await room.requestParticipants();
    } on Object catch (e) {
      debugPrint('group info request participants failed: $e');
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final client = ref.watch(matrixClientProvider);
    final room = client.getRoomById(widget.roomId);
    // 真实成员列表（已加入）；降级到空列表
    final members = room
            ?.getParticipants()
            .where((m) => m.membership == Membership.join)
            .toList() ??
        const <User>[];
    final existingMemberMxids = members
        .map((member) => member.id.trim())
        .where((mxid) => mxid.isNotEmpty)
        .toSet();
    final memberCount = room?.summary.mJoinedMemberCount ?? members.length;

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
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              children: [
                // 成员头像横滚 + 邀请
                M3Card(
                  child: SizedBox(
                    height: 72,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final m in members)
                          _MemberChip(
                            name: m.calcDisplayname(),
                            avatarUrl:
                                matrixContentHttpUrl(client, m.avatarUrl),
                          ),
                        _InviteChip(
                          onTap: () => showInviteGroupMembersFlow(
                            context,
                            ref,
                            roomId: widget.roomId,
                            existingMemberMxids: existingMemberMxids,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 群管理 / 备注
                M3Card(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      InfoNavRow(
                          label: '群管理',
                          onTap: () => context.push(
                              '/group-manage/${Uri.encodeComponent(widget.roomId)}')),
                      const InfoDivider(),
                      InfoNavRow(label: '备注', onTap: () {}),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 查找聊天记录
                M3Card(
                  padding: EdgeInsets.zero,
                  child: InfoNavRow(
                    label: '查找聊天记录',
                    onTap: () => context.push(
                      '/room-search/${Uri.encodeComponent(widget.roomId)}',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 开关组
                M3Card(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      InfoSwitchRow(
                        label: '消息免打扰',
                        value: _mute,
                        onChanged: (v) => setState(() => _mute = v),
                      ),
                      const InfoDivider(),
                      InfoSwitchRow(
                        label: '置顶聊天',
                        value: _pinned,
                        onChanged: (v) => setState(() => _pinned = v),
                      ),
                      const InfoDivider(),
                      InfoNavRow(label: '我在群里的昵称', value: 'Alex', onTap: () {}),
                      const InfoDivider(),
                      InfoSwitchRow(
                        label: '显示群成员昵称',
                        value: _showMemberNick,
                        onChanged: (v) => setState(() => _showMemberNick = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 背景 / 清空
                M3Card(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      InfoNavRow(label: '清空聊天记录', onTap: () {}),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 退出群聊
                M3Card(
                  padding: EdgeInsets.zero,
                  child: InfoCenterRow(
                    label: '退出群聊',
                    danger: true,
                    onTap: () => _confirmLeave(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLeave(BuildContext context) async {
    if (_leaving) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出群聊'),
        content: const Text('确定要退出该群聊吗？'),
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
    if (ok != true || !mounted) return;
    setState(() => _leaving = true);
    try {
      await leaveGroupThroughAs(ref, widget.roomId);
      if (context.mounted) context.go('/home');
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

class _MemberChip extends StatelessWidget {
  const _MemberChip({required this.name, this.avatarUrl});
  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final short = name.split(' ').first;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PortalAvatar(seed: name, size: 48, imageUrl: avatarUrl),
          const SizedBox(height: 4),
          SizedBox(
            width: 52,
            child: Text(
              short,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTheme.sans(size: 10, color: t.textMute),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteChip extends StatelessWidget {
  const _InviteChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: t.border, width: 1.5),
                ),
                child: Icon(Symbols.add, size: 22, color: t.textMute),
              ),
              const SizedBox(height: 4),
              Text('邀请', style: AppTheme.sans(size: 10, color: t.textMute)),
            ],
          ),
        ),
      ),
    );
  }
}
