import 'package:flutter/foundation.dart';

import '../../data/as_client.dart';
import 'channel_share.dart';

void logChannelJoinForbidden(
  Object error, {
  required String source,
  String channelId = '',
  String roomId = '',
  String grantId = '',
  String shareRoomId = '',
  Uri? remoteNodeBaseUri,
  Uri? requesterNodeBaseUri,
  AsChannel? discoveredChannel,
}) {
  if (error is! AsClientException || error.statusCode != 403) return;
  debugPrint(
    '[channel.join.403] '
    'source=$source '
    'error="${error.message}" '
    'channel_id=${_logValue(channelId)} '
    'room_id=${_logValue(roomId)} '
    'grant_id=${_logValue(grantId)} '
    'share_room_id=${_logValue(shareRoomId)} '
    'remote_node=${_logValue(remoteNodeBaseUri?.toString() ?? '')} '
    'requester_node=${_logValue(requesterNodeBaseUri?.toString() ?? '')} '
    'discovered_channel=${_logValue(discoveredChannel?.channelId ?? '')} '
    'discovered_room=${_logValue(discoveredChannel?.roomId ?? '')} '
    'join_policy=${_logValue(discoveredChannel?.joinPolicy ?? '')} '
    'visibility=${_logValue(discoveredChannel?.visibility ?? '')} '
    'member_status=${_logValue(discoveredChannel?.memberStatus ?? '')}',
  );
}

void logChannelShareJoinForbidden(
  Object error, {
  required String source,
  required ChannelSharePayload payload,
}) {
  logChannelJoinForbidden(
    error,
    source: source,
    channelId: payload.channelId,
    roomId: payload.roomId,
    grantId: payload.grantId,
    shareRoomId: payload.shareRoomId,
    discoveredChannel: payload.asDiscoveredChannel,
  );
}

String _logValue(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '<empty>' : trimmed;
}
