class GroupInviteContent {
  const GroupInviteContent({
    required this.groupRoomId,
    required this.groupName,
    this.inviterMxid = '',
    this.inviterDisplayName = '',
    this.inviteEventId = '',
    this.directRoomId = '',
  });

  static const msgTypeV1 = 'p2p.group.invite.v1';
  static const legacyMsgType = 'p2p.group.invite';

  final String groupRoomId;
  final String groupName;
  final String inviterMxid;
  final String inviterDisplayName;
  final String inviteEventId;
  final String directRoomId;

  static GroupInviteContent? tryParse(
    Map<String, Object?> content, {
    String eventId = '',
    String directRoomId = '',
  }) {
    final msgType = _string(content['msgtype']);
    if (msgType != msgTypeV1 && msgType != legacyMsgType) return null;
    final roomId = _string(content['group_room_id']);
    if (roomId.isEmpty) return null;
    final name = _string(content['group_name']);
    return GroupInviteContent(
      groupRoomId: roomId,
      groupName: name.isEmpty ? '群聊' : name,
      inviterMxid: _string(content['inviter_mxid']),
      inviterDisplayName: _string(content['inviter_display_name']),
      inviteEventId: eventId.trim(),
      directRoomId: directRoomId.trim(),
    );
  }
}

String _string(Object? value) {
  if (value is String) return value.trim();
  return '';
}
