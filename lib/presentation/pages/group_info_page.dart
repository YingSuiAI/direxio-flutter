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
import '../providers/as_client_provider.dart';
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
  bool _removingMember = false;
  final Set<String> _locallyRemovedMemberIds = {};

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    final client = ref.read(matrixClientProvider);
    final room = client.getRoomById(widget.roomId);
    if (room == null) return;
    if (client.homeserver == null) {
      if (mounted) setState(() {});
      return;
    }
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
            .where((m) =>
                m.membership == Membership.join &&
                !_locallyRemovedMemberIds.contains(m.id.trim()))
            .toList() ??
        const <User>[];
    final existingMemberMxids = members
        .map((member) => member.id.trim())
        .where((mxid) => mxid.isNotEmpty)
        .toSet();
    final memberCount = room?.summary.mJoinedMemberCount ?? members.length;
    final canManageGroup = room != null && _canManageGroup(room);
    final canDissolveGroup = room != null && _canDissolveGroup(room);

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
                              key: ValueKey('group_info_member_${m.id}'),
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
                          if (canManageGroup)
                            _RemoveMemberChip(
                              onTap: _removingMember
                                  ? null
                                  : () => _showRemoveMemberSheet(
                                        context,
                                        room,
                                        members,
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
                        if (canManageGroup) ...[
                          InfoNavRow(
                            label: '群管理',
                            onTap: () => context.push(
                              '/group-manage/${Uri.encodeComponent(widget.roomId)}',
                            ),
                          ),
                          const InfoDivider(),
                        ],
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
                      label: canDissolveGroup ? '解散群聊' : '退出群聊',
                      danger: true,
                      onTap: () => _confirmLeave(
                        context,
                        dissolve: canDissolveGroup,
                      ),
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

  bool _canManageGroup(Room room) {
    final self = room.client.userID;
    if (self == null || self.isEmpty) return false;
    return room.getPowerLevelByUserId(self) >= 50;
  }

  bool _canDissolveGroup(Room room) {
    final self = room.client.userID;
    if (self == null || self.isEmpty) return false;
    if (room.getState(EventTypes.RoomCreate)?.senderId == self) return true;
    return room.getPowerLevelByUserId(self) >= 100;
  }

  Future<void> _showRemoveMemberSheet(
    BuildContext context,
    Room room,
    List<User> members,
  ) async {
    final self = room.client.userID?.trim() ?? '';
    final selfPower = self.isEmpty ? 0 : room.getPowerLevelByUserId(self);
    final removableMembers = members.where((member) {
      final mxid = member.id.trim();
      if (mxid.isEmpty || mxid == self) return false;
      return room.getPowerLevelByUserId(mxid) < selfPower;
    }).toList();

    if (removableMembers.isEmpty) {
      _toast(context, '暂无可移除成员');
      return;
    }

    final selected = await showModalBottomSheet<User>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.tk.surface,
      builder: (sheetContext) {
        final t = sheetContext.tk;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '移除成员',
                    style: AppTheme.sans(
                      size: 17,
                      weight: FontWeight.w600,
                      color: t.text,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: removableMembers.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: t.surfaceHigh,
                    ),
                    itemBuilder: (_, index) {
                      final member = removableMembers[index];
                      final displayName = member.calcDisplayname();
                      return ListTile(
                        key: ValueKey(
                          'group_info_remove_member_${member.id}',
                        ),
                        contentPadding: EdgeInsets.zero,
                        leading: PortalAvatar(
                          seed: displayName,
                          size: 40,
                          imageUrl: matrixContentHttpUrl(
                            room.client,
                            member.avatarUrl,
                          ),
                        ),
                        title: Text(
                          displayName,
                          style: AppTheme.sans(
                            size: 15,
                            weight: FontWeight.w500,
                            color: t.text,
                          ),
                        ),
                        subtitle: Text(
                          member.id,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.sans(size: 13, color: t.textMute),
                        ),
                        trailing: Icon(
                          Symbols.person_remove,
                          color: t.danger,
                          size: 22,
                        ),
                        onTap: () => Navigator.of(sheetContext).pop(member),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!context.mounted || selected == null) return;
    await _confirmRemoveMember(context, selected);
  }

  Future<void> _confirmRemoveMember(BuildContext context, User member) async {
    if (_removingMember) return;
    final displayName = member.calcDisplayname();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '移除成员',
          style: AppTheme.sans(size: 17, weight: FontWeight.w600),
        ),
        content: Text(
          '确定将 $displayName 移出群聊吗？',
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
              '移除',
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
    await _removeGroupMember(member);
  }

  Future<void> _removeGroupMember(User member) async {
    final peerMxid = member.id.trim();
    if (_removingMember || peerMxid.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final displayName = member.calcDisplayname();
    setState(() => _removingMember = true);
    try {
      await ref.read(asClientProvider).removeGroupMember(
            roomId: widget.roomId,
            peerMxid: peerMxid,
          );
      final room = ref.read(matrixClientProvider).getRoomById(widget.roomId);
      room?.setState(
        StrippedStateEvent(
          type: EventTypes.RoomMember,
          senderId: room.client.userID ?? peerMxid,
          stateKey: peerMxid,
          content: {'membership': Membership.leave.name},
        ),
      );
      if (!mounted) return;
      setState(() => _locallyRemovedMemberIds.add(peerMxid));
      messenger.showSnackBar(SnackBar(content: Text('已移除$displayName')));
      await _fetchMembers();
    } on Object catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('移除成员失败: $e')));
    } finally {
      if (mounted) setState(() => _removingMember = false);
    }
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
          '确定清空当前群聊的所有聊天记录？该操作不可恢复。',
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
      final clearedBeforeTs = DateTime.now().toUtc().millisecondsSinceEpoch + 1;
      await ref.read(asClientProvider).deleteRoomMessagesByRange(
            roomId: widget.roomId,
            fromTs: 0,
            toTs: clearedBeforeTs,
          );
      await ref.read(authStateNotifierProvider.notifier).clearRoomChatHistory(
            widget.roomId,
            clearedBeforeTs: clearedBeforeTs,
          );
      if (!context.mounted) return;
      _toast(context, '聊天记录已清空');
    } on Object catch (e) {
      if (!context.mounted) return;
      _toast(context, '清空聊天记录失败: $e');
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  Future<void> _confirmLeave(
    BuildContext context, {
    required bool dissolve,
  }) async {
    if (_leaving) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          dissolve ? '解散群聊' : '退出群聊',
          style: AppTheme.sans(size: 17, weight: FontWeight.w600),
        ),
        content: Text(
          dissolve ? '确定要解散该群聊吗？' : '确定要退出该群聊吗？',
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
              dissolve ? '解散' : '退出',
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
      if (dissolve) {
        await dissolveGroupThroughAs(ref, widget.roomId);
      } else {
        await leaveGroupThroughAs(ref, widget.roomId);
      }
      if (context.mounted) context.go('/home');
    } on Object catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${dissolve ? '解散' : '退出'}群聊失败: $e')),
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
  const _MemberChip({super.key, required this.name, this.avatarUrl});
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

class _RemoveMemberChip extends StatelessWidget {
  const _RemoveMemberChip({required this.onTap});
  final VoidCallback? onTap;

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
                child: Icon(
                  Symbols.remove,
                  size: 22,
                  color: t.textMute,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '移除',
                style: AppTheme.sans(
                  size: 10,
                  color: t.textMute,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
