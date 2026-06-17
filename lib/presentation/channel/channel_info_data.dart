import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matrix/matrix.dart';

import '../../data/as_client.dart';
import '../mock/mock_channels.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
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
  final String channelType;
  final List<String> tags;
  final int memberCount;
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
    channelType: payload.channelType,
    tags: payload.tags,
    memberCount: 32,
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
    isOwned: channel.role == asChannelRoleOwner ||
        channel.role == asChannelRoleAdmin,
    commentsEnabled: channel.commentsEnabled,
    channelType: channel.channelType,
    tags: channel.tags,
    memberCount: channel.memberCount,
  );
}

ChannelInfoData resolveChannelInfoData(WidgetRef ref, String channelId) {
  final bootstrap = ref.watch(asSyncCacheProvider).bootstrap;
  if (bootstrap != null) {
    final client = ref.watch(matrixClientProvider);
    final channels = ChannelInboxData.fromBootstrap(
      bootstrap,
      fallbackDomain: _clientServerName(client),
    );
    for (final channel in channels) {
      if (channel.id == channelId || channel.roomId == channelId) {
        final bootstrapChannel = _findBootstrapChannel(
          bootstrap,
          channel.id,
          channel.roomId,
        );
        final matrixAvatar = _matrixRoomAvatar(client, channel.roomId);
        return ChannelInfoData(
          id: channel.id,
          roomId: channel.roomId,
          domain: channel.domain,
          name: _displayChannelName(
            channel.name,
            roomId: channel.roomId,
            matrixRoomName: _matrixRoomName(client, channel.roomId),
          ),
          avatarUrl: channel.avatarUrl.trim().isEmpty
              ? matrixAvatar
              : channel.avatarUrl,
          description: _channelDescriptionField(
            bootstrapChannel,
            fallback: channel.description,
          ),
          visibility: channel.visibility,
          joinPolicy: channel.joinPolicy,
          memberStatus: channel.memberStatus,
          isOwned: channel.isOwned ||
              channel.role == asChannelRoleOwner ||
              channel.role == asChannelRoleAdmin,
          commentsEnabled: channel.commentsEnabled,
          channelType: channel.channelType,
          tags: channel.tags,
          memberCount: channel.memberCount,
        );
      }
    }
  }

  final mock = MockChannels.byId(channelId);
  if (mock != null) {
    return ChannelInfoData(
      id: mock.id,
      roomId: mock.id,
      domain: mock.domain,
      name: mock.name,
      avatarUrl: '',
      description: mock.latestMessage,
      visibility: asChannelVisibilityPublic,
      joinPolicy: asChannelJoinPolicyApproval,
      memberStatus: '',
      isOwned: mock.isOwned,
      commentsEnabled: true,
      channelType:
          mock.tags.contains('文字') ? asChannelTypeChat : asChannelTypePost,
      tags: mock.tags,
      memberCount: 32,
    );
  }

  return const ChannelInfoData(
    id: '综合讨论',
    roomId: '综合讨论',
    domain: 'p2p-im.com',
    name: '综合讨论',
    avatarUrl: '',
    description: '',
    visibility: asChannelVisibilityPublic,
    joinPolicy: asChannelJoinPolicyOpen,
    memberStatus: '',
    isOwned: false,
    commentsEnabled: true,
    channelType: asChannelTypeChat,
    tags: ['文字'],
    memberCount: 32,
  );
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
  if (roomName.isNotEmpty && !_looksLikeMatrixRoomId(roomName)) return roomName;
  if (trimmed.isNotEmpty && !_looksLikeMatrixRoomId(trimmed)) return trimmed;
  return '未命名频道';
}

String _matrixRoomName(Client client, String roomId) {
  final room = client.getRoomById(roomId.trim());
  if (room == null) return '';
  return room.getLocalizedDisplayname();
}

String _matrixRoomAvatar(Client client, String roomId) {
  return client.getRoomById(roomId.trim())?.avatar?.toString() ?? '';
}

bool _looksLikeMatrixRoomId(String text) {
  return text.startsWith('!') && text.contains(':');
}
