/// 群「群信息」—— 对齐原型 s-group-info。M3 风格，真实 Matrix 数据。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../chat/chat_glass_background.dart';
import '../groups/group_leave_flow.dart';
import '../groups/group_member_invite_flow.dart';
import '../providers/auth_provider.dart';
import '../providers/conversation_preferences_provider.dart';
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
  bool _showMemberNick = true;
  bool _leaving = false;
  bool _clearing = false;

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
    final client = ref.watch(matrixClientProvider);
    final room = client.getRoomById(widget.roomId);
    final pinnedConversationIds = ref.watch(pinnedConversationIdsProvider);
    final groupRemarkNames = ref.watch(groupRemarkNamesProvider);
    final groupRemark = groupRemarkNames[widget.roomId]?.trim() ?? '';
    final currentNickname = _currentUserNickname(room, client.userID);
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
      backgroundColor: chatPageBackgroundColor(context),
      body: ChatGlassBackground(
        child: Column(
          children: [
            GlassHeader.detail(
              title: '聊天信息($memberCount)',
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
                        InfoNavRow(
                          label: '设置备注',
                          value: groupRemark.isEmpty ? null : groupRemark,
                          onTap: () => _showGroupRemarkDialog(
                            context,
                            currentName: groupRemark.isNotEmpty
                                ? groupRemark
                                : room?.getLocalizedDisplayname() ?? '',
                          ),
                        ),
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
                          value: pinnedConversationIds.contains(widget.roomId),
                          onChanged: (_) {
                            toggleConversationPin(ref, widget.roomId);
                          },
                        ),
                        const InfoDivider(),
                        InfoNavRow(
                          label: '我在本群昵称',
                          value:
                              currentNickname.isEmpty ? null : currentNickname,
                          onTap: room == null
                              ? null
                              : () => _showMyGroupNicknameDialog(
                                    context,
                                    room: room,
                                    currentName: currentNickname,
                                  ),
                        ),
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
                        InfoNavRow(
                          label: '清空聊天记录',
                          onTap: _clearing
                              ? null
                              : () => _confirmClearChatHistory(context),
                        ),
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
      ),
    );
  }

  Future<void> _showGroupRemarkDialog(
    BuildContext context, {
    required String currentName,
  }) async {
    final next = await _showTextEditDialog(
      context,
      title: '备注',
      initialValue: currentName,
      hintText: '输入群聊备注',
    );
    if (!context.mounted || next == null) return;
    setGroupRemarkName(ref, widget.roomId, next);
    _toast(context, next.trim().isEmpty ? '已清除群聊备注' : '群聊备注已更新');
  }

  Future<void> _showMyGroupNicknameDialog(
    BuildContext context, {
    required Room room,
    required String currentName,
  }) async {
    final next = await _showTextEditDialog(
      context,
      title: '我在本群昵称',
      initialValue: currentName,
      hintText: '输入群昵称',
    );
    if (!context.mounted || next == null) return;
    final nickname = next.trim();
    if (nickname.isEmpty) {
      _toast(context, '群昵称不能为空');
      return;
    }
    try {
      final userId = room.client.userID;
      if (userId == null || userId.isEmpty) {
        throw StateError('缺少当前用户信息');
      }
      final content =
          room.getState(EventTypes.RoomMember, userId)?.content.copy() ?? {};
      content['membership'] = Membership.join.name;
      content['displayname'] = nickname;
      await room.client.setRoomStateWithKey(
        room.id,
        EventTypes.RoomMember,
        userId,
        content,
      );
      if (!mounted) return;
      setState(() {});
      _toast(this.context, '群昵称已更新');
    } on Object catch (e) {
      if (!context.mounted) return;
      _toast(context, '设置群昵称失败: $e');
    }
  }

  Future<void> _confirmClearChatHistory(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '清空聊天记录',
          style: AppTheme.sans(size: 17, weight: FontWeight.w600),
        ),
        content: Text(
          '仅清空本机当前群聊的历史记录，新消息仍会正常接收。',
          style: AppTheme.sans(size: 15, color: context.tk.textMute),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              '取消',
              style: AppTheme.sans(size: 15, color: context.tk.textMute),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              '清空',
              style: AppTheme.sans(
                size: 15,
                weight: FontWeight.w600,
                color: context.tk.danger,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted || _clearing) return;
    setState(() => _clearing = true);
    try {
      await ref
          .read(authStateNotifierProvider.notifier)
          .clearRoomChatHistory(widget.roomId);
      if (!context.mounted) return;
      _toast(context, '聊天记录已清空');
    } on Object catch (e) {
      if (!context.mounted) return;
      _toast(context, '清空聊天记录失败: $e');
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  Future<void> _confirmLeave(BuildContext context) async {
    if (_leaving) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '退出群聊',
          style: AppTheme.sans(size: 17, weight: FontWeight.w600),
        ),
        content: Text(
          '确定要退出该群聊吗？',
          style: AppTheme.sans(size: 15, color: context.tk.textMute),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              '取消',
              style: AppTheme.sans(size: 15, color: context.tk.textMute),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              '退出',
              style: AppTheme.sans(
                size: 15,
                weight: FontWeight.w600,
                color: context.tk.danger,
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

Future<String?> _showTextEditDialog(
  BuildContext context, {
  required String title,
  required String initialValue,
  required String hintText,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _GroupTextEditDialog(
      title: title,
      initialValue: initialValue,
      hintText: hintText,
    ),
  );
}

String _currentUserNickname(Room? room, String? userId) {
  final trimmedUserId = userId?.trim() ?? '';
  if (room == null || trimmedUserId.isEmpty) return '';
  final member = room.getState(EventTypes.RoomMember, trimmedUserId);
  final stateName = member?.content.tryGet<String>('displayname')?.trim() ?? '';
  if (stateName.isNotEmpty) return stateName;
  return room
      .unsafeGetUserFromMemoryOrFallback(trimmedUserId)
      .calcDisplayname();
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

class _GroupTextEditDialog extends StatefulWidget {
  const _GroupTextEditDialog({
    required this.title,
    required this.initialValue,
    required this.hintText,
  });

  final String title;
  final String initialValue;
  final String hintText;

  @override
  State<_GroupTextEditDialog> createState() => _GroupTextEditDialogState();
}

class _GroupTextEditDialogState extends State<_GroupTextEditDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AlertDialog(
      title: Text(
        widget.title,
        style: AppTheme.sans(size: 17, weight: FontWeight.w600),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 32,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: AppTheme.sans(size: 15, color: t.textMute),
        ),
        style: AppTheme.sans(size: 15, color: t.text),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            '取消',
            style: AppTheme.sans(size: 15, color: t.textMute),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(
            '保存',
            style: AppTheme.sans(
              size: 15,
              weight: FontWeight.w600,
              color: t.accent,
            ),
          ),
        ),
      ],
    );
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
