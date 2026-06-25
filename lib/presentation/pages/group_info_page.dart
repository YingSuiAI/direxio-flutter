/// 群「群信息」—— 对齐原型 s-group-info。M3 风格，真实 Matrix 数据。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../../data/as_client.dart';
import '../chat/chat_glass_background.dart';
import '../groups/group_leave_flow.dart';
import '../groups/group_member_invite_flow.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/channel_provider.dart';
import '../providers/conversation_preferences_provider.dart';
import '../providers/im_public_client_provider.dart';
import '../providers/matrix_message_clients_provider.dart';
import '../providers/profile_provider.dart';
import '../utils/avatar_url.dart';
import '../utils/group_avatar_members.dart';
import '../widgets/center_toast.dart';
import '../widgets/group_composite_avatar.dart';
import '../widgets/m3/glass_header.dart';
import '../widgets/m3/m3_card.dart';
import '../widgets/portal_avatar.dart';
import '../widgets/info_rows.dart';
import '../widgets/report_reason_dialog.dart';

class GroupInfoPage extends ConsumerStatefulWidget {
  const GroupInfoPage({super.key, required this.roomId});
  final String roomId;

  @override
  ConsumerState<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends ConsumerState<GroupInfoPage> {
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
    final mutedConversationIds = ref.watch(mutedConversationIdsProvider);
    final groupRemarkNames = ref.watch(groupRemarkNamesProvider);
    final groupAvatarMemberOrders = ref.watch(groupAvatarMemberOrdersProvider);
    final groupAvatarMemberAvatars =
        ref.watch(groupAvatarMemberAvatarsProvider);
    final syncCache = ref.watch(asSyncCacheProvider);
    final groupRemark = groupRemarkNames[widget.roomId]?.trim() ?? '';
    final currentUserProfile =
        ref.watch(currentUserProfileProvider).valueOrNull;
    final authoritativeGroupMembers = ref
            .watch(
              groupMembersProvider(
                GroupMembersKey(
                  roomId: widget.roomId,
                  status: asChannelMemberStatusJoined,
                ),
              ),
            )
            .valueOrNull ??
        const <AsGroupMember>[];
    final currentNickname = _currentUserNickname(
      room,
      client.userID,
      currentUserProfile: currentUserProfile,
    );
    final groupName = _groupDisplayName(
      roomId: widget.roomId,
      room: room,
      remark: groupRemark,
      syncCache: syncCache,
    );
    final groupAvatarUrl = room == null ? null : roomAvatarHttpUrl(room);
    final groupAvatarMembers = room == null
        ? null
        : stableGroupAvatarMembersForRoom(
            room: room,
            syncCache: syncCache,
            cachedMemberOrder:
                groupAvatarMemberOrders[widget.roomId] ?? const <String>[],
            cachedMemberAvatarUrls:
                groupAvatarMemberAvatars[widget.roomId] ?? const {},
            authoritativeMembers: authoritativeGroupMembers,
            currentUserProfile: currentUserProfile,
          );
    if (groupAvatarMembers != null) {
      scheduleGroupAvatarMemberOrderPersist(
        ref,
        widget.roomId,
        groupAvatarMembers,
      );
    }
    // 真实成员列表（已加入）；降级到空列表
    final matrixMembers = room
            ?.getParticipants()
            .where((m) =>
                m.membership == Membership.join &&
                !_locallyRemovedMemberIds.contains(m.id.trim()))
            .toList() ??
        const <User>[];
    final members = sortGroupParticipantsByAuthoritativeMembers(
      matrixMembers,
      authoritativeGroupMembers.where((member) {
        final mxid = member.userMxid.trim();
        return mxid.isNotEmpty && !_locallyRemovedMemberIds.contains(mxid);
      }).toList(growable: false),
    );
    final existingMemberMxids = members
        .map((member) => member.id.trim())
        .where((mxid) => mxid.isNotEmpty)
        .toSet();
    final memberPresentations = [
      for (final member in members)
        _groupMemberPresentation(
          client: client,
          room: room,
          member: member,
          authoritativeMember: authoritativeGroupMemberForUser(
            authoritativeGroupMembers,
            member.id,
          ),
          currentUserProfile: currentUserProfile,
        ),
    ];
    final memberCount = _groupInfoMemberCount(
      room: room,
      matrixMembers: members,
      authoritativeMembers: authoritativeGroupMembers,
      locallyRemovedMemberIds: _locallyRemovedMemberIds,
    );
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
                  M3Card(
                    key: ValueKey(
                      'group_info_identity_header_${widget.roomId}',
                    ),
                    child: _GroupIdentityHeader(
                      name: groupName,
                      uid: widget.roomId,
                      avatarUrl: groupAvatarMembers?.members.isEmpty == true
                          ? groupAvatarUrl
                          : null,
                      avatarMembers: groupAvatarMembers?.members ?? const [],
                      seed: widget.roomId,
                      onUidTap: () => _copyGroupUid(context, widget.roomId),
                    ),
                  ),
                  const SizedBox(height: 16),
                  M3Card(
                    child: _GroupMemberGrid(
                      children: [
                        for (final member in memberPresentations)
                          _MemberChip(
                            key: ValueKey('group_info_member_${member.userId}'),
                            userId: member.userId,
                            name: member.name,
                            avatarUrl: member.avatarUrl,
                            onTap: () => _openMemberProfile(member.userId),
                          ),
                        _InviteChip(
                          key: const ValueKey('group_info_invite_member'),
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
                                : groupName,
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
                          value: mutedConversationIds.contains(widget.roomId),
                          onChanged: (v) =>
                              setConversationMuted(ref, widget.roomId, v),
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
                        const InfoDivider(),
                        InfoNavRow(
                          label: '举报群聊',
                          onTap: () => _showReportDialog(context),
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

  void _openMemberProfile(String userId) {
    final mxid = userId.trim();
    if (!mxid.startsWith('@') || !mxid.contains(':')) return;
    final self = ref.read(matrixClientProvider).userID?.trim();
    if (self != null && self == mxid) {
      context.push('/me/profile');
      return;
    }
    context.push('/contact-home/${Uri.encodeComponent(mxid)}');
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
                      final displayName = _groupMemberDisplayName(
                        room: room,
                        member: member,
                      );
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
    final room = ref.read(matrixClientProvider).getRoomById(widget.roomId);
    final displayName = _groupMemberDisplayName(
      room: room,
      member: member,
    );
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
    final room = ref.read(matrixClientProvider).getRoomById(widget.roomId);
    final displayName = _groupMemberDisplayName(
      room: room,
      member: member,
    );
    setState(() => _removingMember = true);
    try {
      await ref.read(asClientProvider).removeGroupMember(
            roomId: widget.roomId,
            peerMxid: peerMxid,
          );
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
      room.setState(
        StrippedStateEvent(
          type: EventTypes.RoomMember,
          senderId: userId,
          stateKey: userId,
          content: Map<String, Object?>.from(content),
        ),
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
      await ref
          .read(matrixMessageVisibilityClientProvider)
          .clearRoom(widget.roomId);
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

  Future<void> _showReportDialog(BuildContext context) async {
    final result = await showDialog<ReportReasonResult>(
      context: context,
      barrierColor: context.tk.text.withValues(alpha: 0.7),
      builder: (_) => const ReportReasonDialog(),
    );
    if (result == null || result.reason.trim().isEmpty || !context.mounted) {
      return;
    }
    final reporterDomain = reportDomainForUserId(
      ref.read(matrixClientProvider).userID ?? '',
      null,
    );
    try {
      await ref.read(imPublicClientProvider).submitReport(
            reporterDomain: reporterDomain,
            reportedDomain: widget.roomId,
            targetType: 2,
            reason: result.reason.trim(),
            files: result.toImPublicFiles(),
          );
      if (!context.mounted) return;
      _toast(context, '举报已提交');
    } catch (error) {
      if (!context.mounted) return;
      _toast(context, '举报提交失败: $error');
    }
  }
}

Future<void> _copyGroupUid(BuildContext context, String uid) async {
  await Clipboard.setData(ClipboardData(text: uid));
  if (!context.mounted) return;
  _toast(context, '已复制 UID');
}

String _groupDisplayName({
  required String roomId,
  required Room? room,
  required String remark,
  required AsSyncCacheState syncCache,
}) {
  return _firstUsableDisplayName([
    remark,
    _productGroupNameForRoom(syncCache, roomId),
    _usableGroupRoomDisplayName(room?.getLocalizedDisplayname() ?? ''),
    roomId,
  ]);
}

String _productGroupNameForRoom(AsSyncCacheState syncCache, String roomId) {
  final targetRoomId = roomId.trim();
  if (targetRoomId.isEmpty) return '';
  for (final group
      in syncCache.bootstrap?.groups ?? const <AsSyncRoomSummary>[]) {
    if (group.roomId.trim() == targetRoomId) {
      return group.name.trim();
    }
  }
  return '';
}

int _groupInfoMemberCount({
  required Room? room,
  required Iterable<User> matrixMembers,
  required Iterable<AsGroupMember> authoritativeMembers,
  required Set<String> locallyRemovedMemberIds,
}) {
  final memberIds = <String>{};
  for (final member in matrixMembers) {
    final mxid = member.id.trim();
    if (mxid.isNotEmpty && !locallyRemovedMemberIds.contains(mxid)) {
      memberIds.add(mxid);
    }
  }
  for (final member in authoritativeMembers) {
    final mxid = member.userMxid.trim();
    if (mxid.isNotEmpty && !locallyRemovedMemberIds.contains(mxid)) {
      memberIds.add(mxid);
    }
  }
  if (memberIds.isNotEmpty) return memberIds.length;
  return room?.summary.mJoinedMemberCount ?? 0;
}

String _usableGroupRoomDisplayName(String value) {
  final name = _usableDisplayName(value);
  if (name.toLowerCase() == 'empty chat') return '';
  return name;
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

String _currentUserNickname(
  Room? room,
  String? userId, {
  required Profile? currentUserProfile,
}) {
  final trimmedUserId = userId?.trim() ?? '';
  if (room == null || trimmedUserId.isEmpty) return '';
  final profileName = _usableDisplayName(
    currentUserProfile?.displayName?.toString() ?? '',
  );
  if (profileName.isNotEmpty) return profileName;
  final member = room.getState(EventTypes.RoomMember, trimmedUserId);
  final stateName = _usableDisplayName(
    member?.content.tryGet<String>('displayname') ?? '',
  );
  if (stateName.isNotEmpty) return stateName;
  final matrixName = _usableDisplayName(
    room.unsafeGetUserFromMemoryOrFallback(trimmedUserId).calcDisplayname(),
  );
  if (matrixName.isNotEmpty) return matrixName;
  return _fallbackDisplayNameFromMxid(trimmedUserId);
}

_GroupMemberPresentation _groupMemberPresentation({
  required Client client,
  required Room? room,
  required User member,
  required AsGroupMember? authoritativeMember,
  required Profile? currentUserProfile,
}) {
  final userId = member.id.trim();
  final isSelf = userId.isNotEmpty && userId == client.userID?.trim();
  final memberState = room?.getState(EventTypes.RoomMember, userId);
  final profileName = isSelf
      ? _usableDisplayName(currentUserProfile?.displayName?.toString() ?? '')
      : '';
  final stateName = _usableDisplayName(
    memberState?.content.tryGet<String>('displayname') ?? '',
  );
  final authoritativeName = _usableDisplayName(
    authoritativeMember?.displayName ?? '',
  );
  final userName = _usableDisplayName(member.calcDisplayname());
  final name = _firstUsableDisplayName([
    profileName,
    authoritativeName,
    stateName,
    userName,
    _fallbackDisplayNameFromMxid(userId),
  ]);
  final profileAvatar =
      isSelf ? profileAvatarHttpUrl(currentUserProfile, client) : null;
  final authoritativeAvatar = avatarHttpUrl(
    client,
    authoritativeMember?.avatarUrl,
  );
  final stateAvatar = avatarHttpUrl(
    client,
    memberState?.content.tryGet<String>('avatar_url'),
  );
  final userAvatar = matrixContentHttpUrl(client, member.avatarUrl);
  return _GroupMemberPresentation(
    userId: userId,
    name: name,
    avatarUrl:
        profileAvatar ?? authoritativeAvatar ?? stateAvatar ?? userAvatar,
  );
}

String _groupMemberDisplayName({
  required Room? room,
  required User member,
}) {
  final userId = member.id.trim();
  final memberState = room?.getState(EventTypes.RoomMember, userId);
  return _firstUsableDisplayName([
    memberState?.content.tryGet<String>('displayname') ?? '',
    member.calcDisplayname(),
    _fallbackDisplayNameFromMxid(userId),
  ]);
}

String _firstUsableDisplayName(Iterable<String> values) {
  for (final value in values) {
    final name = _usableDisplayName(value);
    if (name.isNotEmpty) return name;
  }
  return '';
}

String _usableDisplayName(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.toLowerCase() == 'owner') return '';
  return trimmed;
}

String _fallbackDisplayNameFromMxid(String mxid) {
  final trimmed = mxid.trim();
  if (trimmed.isEmpty) return '';
  if (!trimmed.startsWith('@')) return trimmed;
  final separator = trimmed.indexOf(':');
  if (separator <= 1) return trimmed;
  final localpart = trimmed.substring(1, separator).trim();
  final domain = trimmed.substring(separator + 1).trim();
  if (localpart.toLowerCase() == 'owner' && domain.isNotEmpty) return domain;
  return localpart.isNotEmpty ? localpart : trimmed;
}

void _toast(BuildContext context, String message) {
  showCenterToast(context, message);
}

class _GroupMemberPresentation {
  const _GroupMemberPresentation({
    required this.userId,
    required this.name,
    required this.avatarUrl,
  });

  final String userId;
  final String name;
  final String? avatarUrl;
}

class _GroupIdentityHeader extends StatelessWidget {
  const _GroupIdentityHeader({
    required this.name,
    required this.uid,
    required this.seed,
    required this.onUidTap,
    this.avatarMembers = const [],
    this.avatarUrl,
  });

  final String name;
  final String uid;
  final String seed;
  final VoidCallback onUidTap;
  final List<GroupCompositeAvatarMember> avatarMembers;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SizedBox(
      height: 60,
      child: Row(
        children: [
          GroupCompositeAvatar(
            seed: seed,
            size: 60,
            imageUrl: avatarUrl,
            members: avatarMembers,
            minimumSlots: 4,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(
                    size: 20,
                    weight: FontWeight.w600,
                    color: t.text,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: onUidTap,
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          uid,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.sans(size: 13, color: t.textMute),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Symbols.content_copy,
                        size: 14,
                        color: t.textMute,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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

class _GroupMemberGrid extends StatelessWidget {
  const _GroupMemberGrid({required this.children});

  static const int _columns = 5;
  static const int _maxVisibleRows = 4;
  static const double _tileWidth = 52;
  static const double _tileHeight = 70;
  static const double _gap = 12;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = (children.length / _columns).ceil().clamp(1, _maxVisibleRows);
    final height = rows * _tileHeight + (rows - 1) * _gap;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        const preferredWidth = _columns * _tileWidth + (_columns - 1) * _gap;
        final compactGap =
            (((availableWidth - _columns * _tileWidth) / (_columns - 1))
                    .clamp(4.0, _gap))
                .toDouble();
        final gap = availableWidth < preferredWidth ? compactGap : _gap;
        final contentWidth = _columns * _tileWidth + (_columns - 1) * gap;
        return SizedBox(
          key: const ValueKey('group_info_member_grid'),
          height: height,
          child: SingleChildScrollView(
            primary: false,
            padding: EdgeInsets.zero,
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                key: const ValueKey('group_info_member_grid_content'),
                width: contentWidth,
                child: Wrap(
                  spacing: gap,
                  runSpacing: _gap,
                  children: children,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MemberChip extends StatelessWidget {
  const _MemberChip({
    super.key,
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.onTap,
  });
  final String userId;
  final String name;
  final String? avatarUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final short = name.split(' ').first;
    return SizedBox(
      width: 52,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PortalAvatar(seed: userId, size: 48, imageUrl: avatarUrl),
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
        ),
      ),
    );
  }
}

class _InviteChip extends StatelessWidget {
  const _InviteChip({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SizedBox(
      width: 52,
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
    return SizedBox(
      width: 52,
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
