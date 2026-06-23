import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/as_client.dart';
import 'as_sync_cache_provider.dart';

final productConversationsProvider =
    FutureProvider.autoDispose<List<AsConversation>>((ref) async {
  final bootstrap = ref.watch(asSyncCacheProvider).bootstrap;
  if (bootstrap == null) return const <AsConversation>[];
  return bootstrapProductConversations(bootstrap);
});

List<AsConversation> bootstrapProductConversations(AsSyncBootstrap bootstrap) {
  final conversations = <AsConversation>[];
  final roomSummariesByRoomId = <String, AsSyncRoomSummary>{
    for (final room in bootstrap.rooms)
      if (room.roomId.trim().isNotEmpty) room.roomId.trim(): room,
  };
  final emittedRoomIds = <String>{};

  void add(AsConversation conversation) {
    final roomId = conversation.roomId.trim();
    if (roomId.isEmpty || !emittedRoomIds.add(roomId)) return;
    conversations.add(conversation);
  }

  for (final contact in bootstrap.contacts) {
    final roomId = contact.roomId.trim();
    final status = contact.status.trim();
    if (roomId.isEmpty || status != 'accepted') continue;
    final roomSummary = roomSummariesByRoomId[roomId];
    add(_directConversationFromContact(contact, roomSummary));
  }

  for (final group in bootstrap.groups) {
    add(_roomSummaryConversation(
      group,
      kind: asConversationKindGroup,
      fallbackTitle: '群聊',
      channel: false,
    ));
  }

  for (final channel in bootstrap.channels) {
    add(_roomSummaryConversation(
      channel,
      kind: asConversationKindChannel,
      fallbackTitle: '频道',
      channel: true,
    ));
  }

  final agentRoomId = bootstrap.agentRoomId.trim();
  if (agentRoomId.isNotEmpty && !emittedRoomIds.contains(agentRoomId)) {
    final agentSummary = roomSummariesByRoomId[agentRoomId];
    add(AsConversation(
      conversationId: 'bootstrap:$agentRoomId',
      roomId: agentRoomId,
      kind: asConversationKindAgent,
      lifecycle: _activeLifecycle(agentSummary),
      title: agentSummary?.name.trim().isNotEmpty == true
          ? agentSummary!.name.trim()
          : 'Agent',
      avatarUrl: agentSummary?.avatarUrl.trim() ?? '',
      lastActivityAt: agentSummary?.lastActivityAt,
      memberCount: agentSummary?.memberCount ?? 0,
      membership: _membershipOrJoin(agentSummary?.memberStatus),
      hydrationState: 'ready',
      capabilities: const AsConversationCapabilities(
        open: true,
        send: true,
        sendMedia: true,
        call: true,
      ),
    ));
  }

  return List.unmodifiable(conversations);
}

AsConversation _directConversationFromContact(
  AsSyncContact contact,
  AsSyncRoomSummary? roomSummary,
) {
  final roomId = contact.roomId.trim();
  final title = contact.remark.trim().isNotEmpty
      ? contact.remark.trim()
      : contact.displayName.trim();
  return AsConversation(
    conversationId: 'bootstrap:$roomId',
    roomId: roomId,
    kind: asConversationKindDirect,
    lifecycle: 'active',
    peerMxid: contact.userId.trim(),
    title: title.isNotEmpty ? title : contact.userId.trim(),
    avatarUrl: contact.avatarUrl.trim().isNotEmpty
        ? contact.avatarUrl.trim()
        : roomSummary?.avatarUrl.trim() ?? '',
    lastActivityAt: roomSummary?.lastActivityAt,
    memberCount: roomSummary?.memberCount ?? 2,
    membership: 'join',
    relationshipStatus: contact.status.trim(),
    hydrationState: 'ready',
    capabilities: const AsConversationCapabilities(
      open: true,
      send: true,
      sendMedia: true,
      call: true,
    ),
  );
}

AsConversation _roomSummaryConversation(
  AsSyncRoomSummary summary, {
  required String kind,
  required String fallbackTitle,
  required bool channel,
}) {
  final roomId = summary.roomId.trim();
  final joined = _isJoinedMembership(summary.memberStatus);
  return AsConversation(
    conversationId: summary.channelId.trim().isNotEmpty
        ? summary.channelId.trim()
        : 'bootstrap:$roomId',
    roomId: roomId,
    kind: kind,
    lifecycle: _activeLifecycle(summary),
    title: summary.name.trim().isNotEmpty ? summary.name.trim() : fallbackTitle,
    avatarUrl: summary.avatarUrl.trim(),
    lastActivityAt: summary.lastActivityAt,
    memberCount: summary.memberCount,
    membership: _membershipOrJoin(summary.memberStatus),
    role: summary.role.trim(),
    hydrationState: 'ready',
    capabilities: AsConversationCapabilities(
      open: joined,
      send: joined && !summary.muted,
      sendMedia: joined && !summary.muted,
      call: !channel && joined && !summary.muted,
      invite: !channel && joined,
      manageMembers: _canManageMembers(summary.role),
      rename: _canManageMembers(summary.role),
      removeMembers: _canManageMembers(summary.role),
      leave: joined,
      postCreate: channel && joined && !summary.muted,
      commentCreate: channel && joined && summary.commentsEnabled,
      reactionToggle: channel && joined && !summary.muted,
      commentsEnabled: summary.commentsEnabled,
    ),
  );
}

String _activeLifecycle(AsSyncRoomSummary? summary) {
  final lifecycle = summary?.lifecycle.trim() ?? '';
  return lifecycle.isEmpty ? 'active' : lifecycle;
}

String _membershipOrJoin(String? status) {
  final membership = status?.trim() ?? '';
  return membership.isEmpty ? 'join' : membership;
}

bool _isJoinedMembership(String status) {
  final normalized = status.trim();
  return normalized.isEmpty ||
      normalized == 'join' ||
      normalized == asChannelMemberStatusJoined;
}

bool _canManageMembers(String role) {
  final normalized = role.trim();
  return normalized == asChannelRoleOwner || normalized == asChannelRoleAdmin;
}
