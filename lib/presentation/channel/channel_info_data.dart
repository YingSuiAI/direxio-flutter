import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matrix/matrix.dart';

import '../../data/as_client.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/product_conversations_provider.dart';
import 'channel_inbox_data.dart';
import 'channel_share.dart';

class ChannelInfoData {
  const ChannelInfoData({
    required this.id,
    required this.roomId,
    required this.domain,
    required this.name,
    required this.avatarUrl,
    required this.description,
    required this.visibility,
    required this.joinPolicy,
    required this.memberStatus,
    required this.isOwned,
    required this.commentsEnabled,
    required this.muted,
    required this.channelType,
    required this.tags,
    required this.memberCount,
  });

  final String id;
  final String roomId;
  final String domain;
  final String name;
  final String avatarUrl;
  final String description;
  final String visibility;
  final String joinPolicy;
  final String memberStatus;
  final bool isOwned;
  final bool commentsEnabled;
  final bool muted;
  final String channelType;
  final List<String> tags;
  final int memberCount;
}

String channelDisplayNameWithMemberCount(ChannelInfoData channel) {
  if (channel.memberCount < 0) return channel.name;
  return '${channel.name}（${channel.memberCount}）';
}

ChannelInfoData channelInfoDataFromSharePayload(ChannelSharePayload payload) {
  final description = payload.description.trim();
  final name = _displayChannelName(payload.displayName, roomId: payload.roomId);
  return ChannelInfoData(
    id: payload.channelId.trim(),
    roomId: payload.roomId.trim(),
    domain: payload.homeDomain.trim(),
    name: name,
    avatarUrl: payload.avatarUrl.trim(),
    description: description,
    visibility: payload.visibility,
    joinPolicy: payload.joinPolicy,
    memberStatus: '',
    isOwned: false,
    commentsEnabled: payload.commentsEnabled,
    muted: false,
    channelType: payload.channelType,
    tags: payload.tags,
    memberCount: payload.memberCount,
  );
}

ChannelInfoData channelInfoDataFromAsChannel(AsChannel channel) {
  final roomId = channel.roomId.trim();
  final description = channel.description.trim();
  return ChannelInfoData(
    id: channel.channelId.trim(),
    roomId: roomId,
    domain: channel.homeDomain.trim(),
    name: _displayChannelName(channel.name, roomId: roomId),
    avatarUrl: channel.avatarUrl.trim(),
    description: description,
    visibility: channel.visibility,
    joinPolicy: channel.joinPolicy,
    memberStatus: channel.memberStatus,
    isOwned: channel.role == asChannelRoleOwner,
    commentsEnabled: channel.commentsEnabled,
    muted: channel.muted,
    channelType: channel.channelType,
    tags: channel.tags,
    memberCount: channel.memberCount,
  );
}

ChannelInfoData mergeChannelInfoDataForDetail(
  ChannelInfoData local,
  ChannelInfoData remote,
) {
  return ChannelInfoData(
    id: _preferReadableText(remote.id, local.id),
    roomId: _preferReadableText(remote.roomId, local.roomId),
    domain: _preferReadableText(remote.domain, local.domain),
    name: _preferReadableText(remote.name, local.name),
    avatarUrl: _preferReadableText(remote.avatarUrl, local.avatarUrl),
    description: _preferReadableText(remote.description, local.description),
    visibility: _preferReadableText(remote.visibility, local.visibility),
    joinPolicy: _preferReadableText(remote.joinPolicy, local.joinPolicy),
    memberStatus: _preferReadableText(local.memberStatus, remote.memberStatus),
    isOwned: local.isOwned || remote.isOwned,
    commentsEnabled: remote.commentsEnabled,
    muted: local.muted || remote.muted,
    channelType: _preferReadableText(remote.channelType, local.channelType),
    tags: remote.tags.isEmpty ? local.tags : remote.tags,
    memberCount:
        remote.memberCount > 0 ? remote.memberCount : local.memberCount,
  );
}

ChannelInfoData resolveChannelInfoData(WidgetRef ref, String channelId) {
  final bootstrap = ref.watch(asSyncCacheProvider).bootstrap;
  final productConversations =
      ref.watch(productConversationsProvider).valueOrNull ?? const [];
  if (bootstrap != null) {
    final client = ref.watch(matrixClientProvider);
    final channels = ChannelInboxData.fromBootstrap(
      bootstrap,
      fallbackDomain: _clientServerName(client),
      productConversations: productConversations,
    );
    for (final channel in channels) {
      if (channel.id == channelId || channel.roomId == channelId) {
        final bootstrapChannel = _findBootstrapChannel(
          bootstrap,
          channel.id,
          channel.roomId,
        );
        final matrixAvatar = _matrixRoomAvatar(client, channel.roomId);
        final productAvatar = _findProductConversationAvatar(
          productConversations,
          channel.id,
          channel.roomId,
        );
        return ChannelInfoData(
          id: channel.id,
          roomId: channel.roomId,
          domain: channel.domain,
          name: _displayChannelName(
            channel.name,
            roomId: channel.roomId,
            matrixRoomName: _matrixRoomName(client, channel.roomId),
          ),
          avatarUrl: _preferReadableText(
            channel.avatarUrl,
            _preferReadableText(productAvatar, matrixAvatar),
          ),
          description: _channelDescriptionField(
            bootstrapChannel,
            fallback: channel.description,
          ),
          visibility: channel.visibility,
          joinPolicy: channel.joinPolicy,
          memberStatus: channel.memberStatus,
          isOwned: channel.isOwned || channel.role == asChannelRoleOwner,
          commentsEnabled: channel.commentsEnabled,
          muted: channel.muted || (bootstrapChannel?.muted ?? false),
          channelType: channel.channelType,
          tags: channel.tags,
          memberCount: channel.memberCount,
        );
      }
    }
  }

  final trimmed = channelId.trim();
  return ChannelInfoData(
    id: trimmed,
    roomId: trimmed,
    domain: '',
    name: trimmed.isEmpty ? '频道' : trimmed,
    avatarUrl: '',
    description: '',
    visibility: asChannelVisibilityPublic,
    joinPolicy: asChannelJoinPolicyOpen,
    memberStatus: '',
    isOwned: false,
    commentsEnabled: true,
    muted: false,
    channelType: asChannelTypeChat,
    tags: const [],
    memberCount: -1,
  );
}

String _findProductConversationAvatar(
  Iterable<AsConversation> conversations,
  String channelId,
  String roomId,
) {
  final targetChannelId = channelId.trim();
  final targetRoomId = roomId.trim();
  for (final conversation in conversations) {
    if (!conversation.isChannel) continue;
    final conversationId = conversation.conversationId.trim();
    final conversationRoomId = conversation.roomId.trim();
    final matchesChannel =
        targetChannelId.isNotEmpty && conversationId == targetChannelId;
    final matchesRoom = targetRoomId.isNotEmpty &&
        (conversationRoomId == targetRoomId || conversationId == targetRoomId);
    if (!matchesChannel && !matchesRoom) continue;
    final avatar = conversation.avatarUrl.trim();
    if (avatar.isNotEmpty) return avatar;
  }
  return '';
}

String _clientServerName(Client client) {
  final userId = client.userID ?? '';
  final fromMxid = _serverNameFromMxid(userId);
  if (fromMxid != null && fromMxid.isNotEmpty) return fromMxid;
  final homeserver = client.homeserver;
  if (homeserver != null && homeserver.host.isNotEmpty) return homeserver.host;
  return 'p2p-im.com';
}

AsSyncRoomSummary? _findBootstrapChannel(
  AsSyncBootstrap bootstrap,
  String channelId,
  String roomId,
) {
  final targetChannelId = channelId.trim();
  final targetRoomId = roomId.trim();
  for (final channel in bootstrap.channels) {
    if (targetChannelId.isNotEmpty &&
        channel.channelId.trim() == targetChannelId) {
      return channel;
    }
    if (targetRoomId.isNotEmpty && channel.roomId.trim() == targetRoomId) {
      return channel;
    }
  }
  return null;
}

String _channelDescriptionField(
  AsSyncRoomSummary? channel, {
  required String fallback,
}) {
  final description = channel?.description.trim() ?? '';
  if (description.isNotEmpty) return description;
  return fallback.trim();
}

String _preferReadableText(String primary, String? fallback) {
  final first = primary.trim();
  if (first.isNotEmpty) return first;
  return fallback?.trim() ?? '';
}

String? _serverNameFromMxid(String mxid) {
  final index = mxid.indexOf(':');
  if (index < 0 || index == mxid.length - 1) return null;
  return mxid.substring(index + 1);
}

String _displayChannelName(
  String name, {
  required String roomId,
  String? matrixRoomName,
}) {
  final trimmed = name.trim();
  final roomName = matrixRoomName?.trim() ?? '';
  if (_isUsableChannelDisplayName(roomName)) return roomName;
  if (trimmed.isNotEmpty && !_looksLikeMatrixRoomId(trimmed)) return trimmed;
  return '未命名频道';
}

String _matrixRoomName(Client client, String roomId) {
  final room = client.getRoomById(roomId.trim());
  if (room == null) return '';
  final name = room.getLocalizedDisplayname().trim();
  return _isUsableChannelDisplayName(name) ? name : '';
}

String _matrixRoomAvatar(Client client, String roomId) {
  return client.getRoomById(roomId.trim())?.avatar?.toString() ?? '';
}

bool _looksLikeMatrixRoomId(String text) {
  return text.startsWith('!') && text.contains(':');
}

bool _isUsableChannelDisplayName(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty || _looksLikeMatrixRoomId(trimmed)) return false;
  return trimmed != 'Empty chat';
}
