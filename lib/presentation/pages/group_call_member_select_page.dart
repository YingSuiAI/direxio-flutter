import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../call/voice_call_controller.dart';
import '../providers/auth_provider.dart';
import '../utils/avatar_url.dart';
import '../widgets/app_glass_background.dart';
import '../widgets/glass_list_tile.dart';
import '../widgets/m3/glass_header.dart';
import '../widgets/m3/m3_card.dart';
import '../widgets/portal_avatar.dart';

class GroupCallInviteMember {
  const GroupCallInviteMember({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
}

String groupCallInviteRoute({
  required String roomId,
  required String roomName,
  required ProductCallType callType,
}) {
  return '/group-call-invite/${Uri.encodeComponent(roomId)}'
      '?name=${Uri.encodeComponent(roomName)}'
      '&type=${_callTypeQueryValue(callType)}';
}

String groupCallStartRoute({
  required String roomId,
  required String roomName,
  required ProductCallType callType,
  Iterable<String> inviteeIds = const [],
}) {
  final path =
      callType == ProductCallType.video ? '/group-video-call' : '/group-call';
  final invitees = inviteeIds
      .where((id) => id.trim().isNotEmpty)
      .map(Uri.encodeComponent)
      .join(',');
  final inviteeQuery = invitees.isEmpty ? '' : '&invitees=$invitees';
  return '$path/${Uri.encodeComponent(roomId)}'
      '?name=${Uri.encodeComponent(roomName)}'
      '$inviteeQuery';
}

String groupCallJoinRoute({
  required String roomId,
  required String roomName,
  required ProductCallType callType,
  required String callId,
  bool incoming = true,
}) {
  final path =
      callType == ProductCallType.video ? '/group-video-call' : '/group-call';
  final incomingQuery = incoming ? '&incoming=1' : '';
  return '$path/${Uri.encodeComponent(roomId)}'
      '?name=${Uri.encodeComponent(roomName)}'
      '&call_id=${Uri.encodeComponent(callId)}'
      '$incomingQuery';
}

ProductCallType groupCallTypeFromQuery(String? value) {
  return value == 'video' ? ProductCallType.video : ProductCallType.voice;
}

List<String> groupCallInviteesFromQuery(String? value) {
  if (value == null || value.trim().isEmpty) return const [];
  final seen = <String>{};
  final result = <String>[];
  for (final part in value.split(',')) {
    final decoded = Uri.decodeComponent(part).trim();
    if (decoded.isEmpty || seen.contains(decoded)) continue;
    seen.add(decoded);
    result.add(decoded);
  }
  return result;
}

void replaceGroupCallInviteSelection(BuildContext context, String location) {
  context.replace(location);
}

String _callTypeQueryValue(ProductCallType callType) {
  return callType == ProductCallType.video ? 'video' : 'voice';
}

List<GroupCallInviteMember> groupCallInviteMembersFromRoom(
  Room room, {
  required String? currentUserId,
}) {
  final byUserId = <String, GroupCallInviteMember>{};
  for (final member in room.getParticipants()) {
    final userId = member.id.trim();
    if (userId.isEmpty ||
        userId == currentUserId ||
        member.membership != Membership.join) {
      continue;
    }
    final displayName = member.calcDisplayname().trim();
    byUserId[userId] = GroupCallInviteMember(
      userId: userId,
      displayName: displayName.isEmpty ? userId : displayName,
      avatarUrl: matrixContentHttpUrl(room.client, member.avatarUrl),
    );
  }
  final members = byUserId.values.toList()
    ..sort((a, b) => a.displayName.compareTo(b.displayName));
  return members;
}

class GroupCallMemberSelectPage extends ConsumerStatefulWidget {
  const GroupCallMemberSelectPage({
    super.key,
    required this.roomId,
    required this.roomName,
    required this.callType,
  });

  final String roomId;
  final String? roomName;
  final ProductCallType callType;

  @override
  ConsumerState<GroupCallMemberSelectPage> createState() =>
      _GroupCallMemberSelectPageState();
}

class _GroupCallMemberSelectPageState
    extends ConsumerState<GroupCallMemberSelectPage> {
  late Future<List<GroupCallInviteMember>> _membersFuture;

  @override
  void initState() {
    super.initState();
    _membersFuture = _loadMembers();
  }

  Future<List<GroupCallInviteMember>> _loadMembers() async {
    final client = ref.read(matrixClientProvider);
    final room = client.getRoomById(widget.roomId);
    if (room == null) return const [];
    try {
      await room.requestParticipants();
    } on Object {
      // 保留本地已同步成员，避免网络波动时成员选择页直接不可用。
    }
    return groupCallInviteMembersFromRoom(
      room,
      currentUserId: client.userID,
    );
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(matrixClientProvider);
    final room = client.getRoomById(widget.roomId);
    final roomName = widget.roomName ?? room?.getLocalizedDisplayname() ?? '群聊';
    return FutureBuilder<List<GroupCallInviteMember>>(
      future: _membersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _GroupCallSelectScaffold(
            roomName: roomName,
            callType: widget.callType,
            child: const Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          );
        }

        return GroupCallMemberSelectView(
          roomName: roomName,
          callType: widget.callType,
          members: snapshot.data ?? const [],
          onStart: (invitees) {
            if (invitees.isEmpty) return;
            replaceGroupCallInviteSelection(
              context,
              groupCallStartRoute(
                roomId: widget.roomId,
                roomName: roomName,
                callType: widget.callType,
                inviteeIds: invitees,
              ),
            );
          },
        );
      },
    );
  }
}

class GroupCallMemberSelectView extends StatefulWidget {
  const GroupCallMemberSelectView({
    super.key,
    required this.roomName,
    required this.callType,
    required this.members,
    required this.onStart,
  });

  final String roomName;
  final ProductCallType callType;
  final List<GroupCallInviteMember> members;
  final ValueChanged<List<String>> onStart;

  @override
  State<GroupCallMemberSelectView> createState() =>
      _GroupCallMemberSelectViewState();
}

class _GroupCallMemberSelectViewState extends State<GroupCallMemberSelectView> {
  final Set<String> _selectedUserIds = {};

  bool get _isVideo => widget.callType == ProductCallType.video;

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedUserIds.length;
    return _GroupCallSelectScaffold(
      roomName: widget.roomName,
      callType: widget.callType,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              glassListTileHorizontalMargin,
              12,
              glassListTileHorizontalMargin,
              8,
            ),
            child: _SelectedSummary(
              selectedCount: selectedCount,
              totalCount: widget.members.length,
              isVideo: _isVideo,
            ),
          ),
          Expanded(
            child: widget.members.isEmpty
                ? const _EmptyMemberState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 18),
                    itemCount: widget.members.length,
                    itemBuilder: (context, index) {
                      final member = widget.members[index];
                      final selected = _selectedUserIds.contains(member.userId);
                      return _InviteMemberTile(
                        member: member,
                        selected: selected,
                        onTap: () => _toggle(member.userId),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: M3PrimaryButton(
              label: _isVideo ? '发起视频通话' : '发起语音通话',
              icon: _isVideo ? Symbols.videocam : Symbols.call,
              onPressed: selectedCount == 0
                  ? null
                  : () => widget.onStart(_selectedUserIds.toList()),
            ),
          ),
        ],
      ),
    );
  }

  void _toggle(String userId) {
    setState(() {
      if (!_selectedUserIds.add(userId)) {
        _selectedUserIds.remove(userId);
      }
    });
  }
}

class _GroupCallSelectScaffold extends StatelessWidget {
  const _GroupCallSelectScaffold({
    required this.roomName,
    required this.callType,
    required this.child,
  });

  final String roomName;
  final ProductCallType callType;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isVideo = callType == ProductCallType.video;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGlassBackground(
        child: Column(
          children: [
            GlassHeader.detail(
              title: isVideo ? '选择视频成员' : '选择语音成员',
              subtitle: roomName,
              subtitleIcon: Symbols.groups,
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _SelectedSummary extends StatelessWidget {
  const _SelectedSummary({
    required this.selectedCount,
    required this.totalCount,
    required this.isVideo,
  });

  final int selectedCount;
  final int totalCount;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AppGlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            isVideo ? Symbols.videocam : Symbols.call,
            color: t.textMute,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              selectedCount == 0
                  ? '选择至少 1 名成员发起邀请'
                  : '已选择 $selectedCount / $totalCount 名成员',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.sans(
                size: 15,
                color: selectedCount == 0 ? t.textMute : t.text,
                weight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteMemberTile extends StatelessWidget {
  const _InviteMemberTile({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  final GroupCallInviteMember member;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return GlassListTile(
      title: member.displayName,
      subtitle: member.userId,
      leading: PortalAvatar(
        seed: member.displayName,
        imageUrl: member.avatarUrl,
        size: 46,
      ),
      trailing: Icon(
        selected ? Symbols.check_circle : Symbols.circle,
        size: 25,
        fill: selected ? 1 : 0,
        color: selected ? t.accent : t.textMute,
      ),
      showChevron: false,
      onTap: onTap,
    );
  }
}

class _EmptyMemberState extends StatelessWidget {
  const _EmptyMemberState();

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          '暂无可邀请成员',
          textAlign: TextAlign.center,
          style: AppTheme.sans(size: 16, color: t.textMute),
        ),
      ),
    );
  }
}
