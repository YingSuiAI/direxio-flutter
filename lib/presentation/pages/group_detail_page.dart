import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../../l10n/app_localizations.dart';
import '../groups/group_leave_flow.dart';
import '../groups/group_member_invite_flow.dart';
import '../providers/auth_provider.dart';
import '../providers/channel_provider.dart';
import '../providers/conversation_preferences_provider.dart';
import '../providers/matrix_message_clients_provider.dart';
import '../providers/profile_provider.dart';
import '../utils/avatar_url.dart';
import '../utils/contact_display_name.dart';
import '../utils/group_avatar_members.dart';
import '../widgets/portal_avatar.dart';
import '../widgets/m3/glass_header.dart';
import '../widgets/center_toast.dart';

/// GROUP INFO 屏 —— 1:1 复刻 P2P-APP-UI/index.html 中 #s-group-info（678-808 行）。
/// 保留 Riverpod / Matrix client 数据查询；widget 树严格对齐设计稿。
class GroupDetailPage extends ConsumerStatefulWidget {
  const GroupDetailPage({
    super.key,
    required this.roomId,
    this.displayName,
    this.avatarUrl,
    this.scannedQr = false,
  });

  final String roomId;
  final String? displayName;
  final String? avatarUrl;
  final bool scannedQr;

  @override
  ConsumerState<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends ConsumerState<GroupDetailPage> {
  bool _showNicknames = true;
  bool _leaving = false;
  bool _clearing = false;

  @override
  Widget build(BuildContext context) {
    final client = ref.read(matrixClientProvider);
    final room = client.getRoomById(widget.roomId);
    final pinnedConversationIds = ref.watch(pinnedConversationIdsProvider);
    final mutedConversationIds = ref.watch(mutedConversationIdsProvider);
    final groupRemarkNames = ref.watch(groupRemarkNamesProvider);
    final groupRemark = groupRemarkNames[widget.roomId]?.trim() ?? '';
    final currentUserProfile =
        ref.watch(currentUserProfileProvider).valueOrNull;
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
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
    if (room == null) {
      final scannedDisplayName = _usableDisplayName(widget.displayName ?? '');
      final scannedAvatarUrl = avatarHttpUrl(client, widget.avatarUrl);
      _logGroupDetail(
        'room missing roomId=${widget.roomId} scannedQr=${widget.scannedQr} '
        'hasName=${scannedDisplayName.isNotEmpty} hasAvatar=${scannedAvatarUrl != null}',
      );
      if (widget.scannedQr ||
          scannedDisplayName.isNotEmpty ||
          scannedAvatarUrl != null) {
        _logGroupDetail('show scanned item roomId=${widget.roomId}');
        return Scaffold(
          backgroundColor: context.tk.bg,
          body: Column(
            children: [
              GlassHeader.detail(
                title: l10n?.groupDetailChatInfoTitle(0) ?? '聊天信息(0)',
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                  child: _ScannedGroupQrCard(
                    displayName: scannedDisplayName.isNotEmpty
                        ? scannedDisplayName
                        : widget.roomId,
                    roomId: widget.roomId,
                    avatarUrl: scannedAvatarUrl,
                  ),
                ),
              ),
            ],
          ),
        );
      }
      _logGroupDetail('show missing state roomId=${widget.roomId}');
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: Text(l10n?.groupDetailMissing ?? '群组不存在')),
      );
    }

    final currentNickname = _currentUserNickname(
      room,
      client.userID,
      currentUserProfile: currentUserProfile,
    );
    final realMembers = sortGroupParticipantsByAuthoritativeMembers(
      room.getParticipants(),
      authoritativeGroupMembers,
    );
    final existingMemberMxids = realMembers
        .map((member) => member.id.trim())
        .where((mxid) => mxid.isNotEmpty)
        .toSet();
    final members = _buildMemberStripData(
      realMembers,
      client: client,
      authoritativeMembers: authoritativeGroupMembers,
      currentUserProfile: currentUserProfile,
    );
    final memberCount = authoritativeGroupMembers.isNotEmpty
        ? authoritativeGroupMembers.length
        : realMembers.length;
    final canManageGroup = _canManageGroup(room);
    final canDissolveGroup = _canDissolveGroup(room);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          GlassHeader.detail(
            title: l10n?.groupDetailChatInfoTitle(memberCount) ??
                '聊天信息($memberCount)',
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
                      if (canManageGroup) ...[
                        _RowChevron(
                          label: '群管理',
                          onTap: () => context.push(
                            '/group-manage/${Uri.encodeComponent(widget.roomId)}',
                          ),
                        ),
                        _Divider(),
                      ],
                      _RowChevron(
                        label: '设置备注',
                        trailingText: groupRemark.isEmpty ? null : groupRemark,
                        onTap: () => _showGroupRemarkDialog(
                          context,
                          currentName: groupRemark.isNotEmpty
                              ? groupRemark
                              : safeRoomDisplayName(room),
                        ),
                      ),
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
                        value: mutedConversationIds.contains(widget.roomId),
                        onChanged: (v) =>
                            setConversationMuted(ref, widget.roomId, v),
                      ),
                      _Divider(),
                      _RowSwitch(
                        label: '置顶聊天',
                        value: pinnedConversationIds.contains(widget.roomId),
                        onChanged: (_) =>
                            toggleConversationPin(ref, widget.roomId),
                      ),
                      _Divider(),
                      _RowChevron(
                        label: '我在本群昵称',
                        trailingText:
                            currentNickname.isEmpty ? null : currentNickname,
                        onTap: () => _showMyGroupNicknameDialog(
                          context,
                          room: room,
                          currentName: currentNickname,
                        ),
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
                      _RowChevron(
                        label: '清空聊天记录',
                        onTap: _clearing
                            ? () {}
                            : () => _confirmClearChatHistory(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _GroupedCard(
                    children: [
                      _RowDanger(
                        label: canDissolveGroup ? '解散群聊' : '退出群聊',
                        onTap: () => _confirmLeave(
                          context,
                          dissolve: canDissolveGroup,
                        ),
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
    required List<AsGroupMember> authoritativeMembers,
    required Profile? currentUserProfile,
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
    final out = <_Member>[];
    for (var i = 0; i < real.length; i++) {
      final userId = real[i].id.trim();
      final isSelf = userId.isNotEmpty && userId == client.userID?.trim();
      final profileName = isSelf
          ? _usableDisplayName(
              currentUserProfile?.displayName?.toString() ?? '')
          : '';
      final authoritativeMember = authoritativeGroupMemberForUser(
        authoritativeMembers,
        userId,
      );
      final authoritativeName = _usableDisplayName(
        authoritativeMember?.displayName ?? '',
      );
      final name = _firstUsableDisplayName([
        authoritativeName,
        real[i].displayName ?? '',
        profileName,
        real[i].calcDisplayname(),
        _fallbackDisplayNameFromMxid(userId),
      ]);
      final authoritativeAvatar = avatarHttpUrl(
        client,
        authoritativeMember?.avatarUrl,
      );
      out.add(
        _Member(
          initial:
              (name.isNotEmpty ? name : userId).characters.first.toUpperCase(),
          name: name,
          avatarUrl: authoritativeAvatar ??
              matrixContentHttpUrl(client, real[i].avatarUrl),
          bg: palette[i % palette.length],
          fg: onColors[i % onColors.length],
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

  bool _canDissolveGroup(Room room) {
    final self = room.client.userID;
    if (self == null || self.isEmpty) return false;
    if (room.getState(EventTypes.RoomCreate)?.senderId == self) return true;
    return room.getPowerLevelByUserId(self) >= 100;
  }

  Future<void> _showGroupRemarkDialog(
    BuildContext context, {
    required String currentName,
  }) async {
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final next = await _showTextEditDialog(
      context,
      title: l10n?.groupInfoRemarkTitle ?? '备注',
      initialValue: currentName,
      hintText: l10n?.groupInfoRemarkHint ?? '输入群聊备注',
    );
    if (!context.mounted || next == null) return;
    setGroupRemarkName(ref, widget.roomId, next);
    _toast(
      context,
      next.trim().isEmpty
          ? l10n?.groupInfoRemarkCleared ?? '已清除群聊备注'
          : l10n?.groupInfoRemarkUpdated ?? '群聊备注已更新',
    );
  }

  Future<void> _showMyGroupNicknameDialog(
    BuildContext context, {
    required Room room,
    required String currentName,
  }) async {
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final next = await _showTextEditDialog(
      context,
      title: l10n?.groupInfoMyNickname ?? '我在本群昵称',
      initialValue: currentName,
      hintText: l10n?.groupInfoNicknameHint ?? '输入群昵称',
    );
    if (!context.mounted || next == null) return;
    final nickname = next.trim();
    if (nickname.isEmpty) {
      _toast(context, l10n?.groupInfoNicknameEmpty ?? '群昵称不能为空');
      return;
    }
    String? userId;
    Map<String, Object?>? previousContent;
    try {
      userId = room.client.userID;
      if (userId == null || userId.isEmpty) {
        throw StateError(l10n?.groupInfoCurrentUserMissing ?? '缺少当前用户信息');
      }
      final currentContent =
          room.getState(EventTypes.RoomMember, userId)?.content.copy();
      previousContent = currentContent == null
          ? null
          : Map<String, Object?>.from(currentContent);
      final content = Map<String, Object?>.from(
        currentContent ?? const <String, Object?>{},
      );
      content['membership'] = Membership.join.name;
      content['displayname'] = nickname;
      _setLocalRoomMemberState(room, userId, content);
      if (mounted) setState(() {});
      await room.client.setRoomStateWithKey(
        room.id,
        EventTypes.RoomMember,
        userId,
        content,
      );
      if (!mounted) return;
      setState(() {});
      _toast(this.context, l10n?.groupInfoNicknameUpdated ?? '群昵称已更新');
    } on Object catch (e) {
      if (userId != null && userId.isNotEmpty && previousContent != null) {
        _setLocalRoomMemberState(room, userId, previousContent);
      }
      if (!context.mounted) return;
      if (mounted) setState(() {});
      _toast(
        context,
        l10n?.groupInfoNicknameUpdateFailed('$e') ?? '设置群昵称失败: $e',
      );
    }
  }

  Future<void> _confirmClearChatHistory(BuildContext context) async {
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          l10n?.chatInfoClearHistory ?? '清空聊天记录',
          style: AppTheme.sans(size: 17, weight: FontWeight.w600),
        ),
        content: Text(
          l10n?.groupInfoClearHistoryConfirm ?? '确定清空当前群聊的所有聊天记录？该操作不可恢复。',
          style: AppTheme.sans(size: 15, color: context.tk.textMute),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(
              l10n?.commonCancel ?? '取消',
              style: AppTheme.sans(size: 15, color: context.tk.textMute),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(
              l10n?.chatInfoClearHistoryAction ?? '清空',
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
      _toast(context, l10n?.chatInfoClearHistoryCleared ?? '聊天记录已清空');
    } on Object catch (e) {
      if (!context.mounted) return;
      _toast(
        context,
        l10n?.chatInfoClearHistoryFailed('$e') ?? '清空聊天记录失败: $e',
      );
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  Future<void> _confirmLeave(
    BuildContext context, {
    required bool dissolve,
  }) async {
    if (_leaving) return;
    final t = context.tk;
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final dissolveAction = l10n?.groupDetailDissolveAction ?? '解散';
    final leaveAction = l10n?.groupDetailLeaveAction ?? '退出';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          dissolve
              ? l10n?.groupDetailDissolveTitle ?? '解散群聊'
              : l10n?.groupDetailLeaveTitle ?? '退出群聊',
          style: AppTheme.sans(size: 17, weight: FontWeight.w600),
        ),
        content: Text(
          dissolve
              ? l10n?.groupDetailDissolveMessage ?? '解散后群聊将从当前服务移除。'
              : l10n?.groupDetailLeaveMessage ?? '退出后你将不再接收该群聊消息。',
          style: AppTheme.sans(size: 15, color: t.textMute),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(
              l10n?.commonCancel ?? '取消',
              style: AppTheme.sans(size: 15, color: t.textMute),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(
              dissolve ? dissolveAction : leaveAction,
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
      if (dissolve) {
        await dissolveGroupThroughAs(ref, widget.roomId);
      } else {
        await leaveGroupThroughAs(ref, widget.roomId);
      }
      if (!context.mounted) return;
      context.go('/home');
    } on Object catch (e) {
      if (!context.mounted) return;
      showTopSnackBar(
        context,
        SnackBar(
          content: Text(
            l10n?.groupDetailLeaveOrDissolveFailed(
                  dissolve ? dissolveAction : leaveAction,
                  '$e',
                ) ??
                '${dissolve ? dissolveAction : leaveAction}群聊失败: $e',
          ),
        ),
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
  final member = room.getState(EventTypes.RoomMember, trimmedUserId);
  final stateName = _usableDisplayName(
    member?.content.tryGet<String>('displayname') ?? '',
  );
  if (stateName.isNotEmpty) return stateName;
  if (profileName.isNotEmpty) return profileName;
  return _fallbackDisplayNameFromMxid(trimmedUserId);
}

void _setLocalRoomMemberState(
  Room room,
  String userId,
  Map<String, Object?> content,
) {
  room.setState(
    StrippedStateEvent(
      type: EventTypes.RoomMember,
      senderId: userId,
      stateKey: userId,
      content: Map<String, Object?>.from(content),
    ),
  );
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
  showTopSnackBar(
    context,
    SnackBar(content: Text(message)),
  );
}

void _logGroupDetail(String message) {
  debugPrint('group-detail $message');
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
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
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
            l10n?.commonCancel ?? '取消',
            style: AppTheme.sans(size: 15, color: t.textMute),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(
            l10n?.commonSave ?? '保存',
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
  static const int _columns = 4;
  static const double _tileHeight = 70;
  static const double _expandedHeight = 152;

  final List<_Member> members;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final children = <Widget>[
      for (final member in members) _MemberTile(member: member),
      _InviteTile(onTap: onInvite),
    ];
    final height = children.length > _columns ? _expandedHeight : _tileHeight;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border.withValues(alpha: 0.3)),
      ),
      child: SizedBox(
        key: const ValueKey('group_detail_member_grid'),
        height: height,
        child: GridView.builder(
          primary: false,
          padding: EdgeInsets.zero,
          itemCount: children.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: _tileHeight,
          ),
          itemBuilder: (context, index) => Align(
            alignment: Alignment.topCenter,
            child: children[index],
          ),
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
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
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
            Text(
              l10n?.groupDetailInvite ?? '邀请',
              style: AppTheme.sans(size: 10, color: t.textMute),
            ),
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

class _ScannedGroupQrCard extends StatelessWidget {
  const _ScannedGroupQrCard({
    required this.displayName,
    required this.roomId,
    required this.avatarUrl,
  });

  final String displayName;
  final String roomId;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          PortalAvatar(
            seed: displayName.isNotEmpty ? displayName : roomId,
            size: 60,
            imageUrl: avatarUrl,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(
                    size: 17,
                    weight: FontWeight.w600,
                    color: t.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n?.groupQrId(roomId) ?? 'ID $roomId',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(size: 14, color: t.textMute),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
