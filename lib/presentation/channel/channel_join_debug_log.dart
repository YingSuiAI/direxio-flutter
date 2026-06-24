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

void logChannelShareJoinError(
  Object error, {
  required String source,
  required ChannelSharePayload payload,
}) {
  debugPrint(
    '[channel.share.join.error] '
    'source=$source '
    'error_type=${error.runtimeType} '
    'status_code=${error is AsClientException ? error.statusCode : 0} '
    'error="${error is AsClientException ? error.message : '$error'}" '
    'channel_id=${_logValue(payload.channelId)} '
    'room_id=${_logValue(payload.roomId)} '
    'has_grant=${channelShareHasInviteGrant(payload)} '
    'grant_id=${_logValue(payload.grantId)} '
    'share_room_id=${_logValue(payload.shareRoomId)} '
    'join_policy=${_logValue(payload.joinPolicy)} '
    'visibility=${_logValue(payload.visibility)}',
  );
}

void logChannelShareJoinStart({
  required String source,
  required ChannelSharePayload payload,
  required String action,
  required String targetId,
}) {
  debugPrint(
    '[channel.share.join.start] '
    'source=$source '
    'action=$action '
    'target=${_logValue(targetId)} '
    'channel_id=${_logValue(payload.channelId)} '
    'room_id=${_logValue(payload.roomId)} '
    'has_grant=${channelShareHasInviteGrant(payload)} '
    'grant_id=${_logValue(payload.grantId)} '
    'share_room_id=${_logValue(payload.shareRoomId)} '
    'join_policy=${_logValue(payload.joinPolicy)} '
    'visibility=${_logValue(payload.visibility)} '
    'channel_type=${_logValue(payload.channelType)}',
  );
}

void logChannelShareJoinResult({
  required String source,
  required ChannelSharePayload payload,
  required AsChannel channel,
  required String stage,
}) {
  debugPrint(
    '[channel.share.join.result] '
    'source=$source '
    'stage=$stage '
    'payload_channel_id=${_logValue(payload.channelId)} '
    'payload_room_id=${_logValue(payload.roomId)} '
    'result_channel_id=${_logValue(channel.channelId)} '
    'result_room_id=${_logValue(channel.roomId)} '
    'member_status=${_logValue(channel.memberStatus)} '
    'role=${_logValue(channel.role)} '
    'channel_type=${_logValue(channel.channelType)} '
    'conversation_id=${_logValue(channel.productConversation?.conversationId ?? '')} '
    'conversation_room=${_logValue(channel.productConversation?.roomId ?? '')} '
    'conversation_open=${channel.productConversation?.canOpen ?? false}',
  );
}

void logChannelJoinProjection({
  required String source,
  required String channelId,
  required String roomId,
  required int attempt,
  String result = '',
  AsChannel? channel,
  Object? error,
}) {
  debugPrint(
    '[channel.join.projection] '
    'source=$source '
    'attempt=$attempt '
    'target_channel_id=${_logValue(channelId)} '
    'target_room_id=${_logValue(roomId)} '
    'result=${_logValue(result)} '
    'projected_channel_id=${_logValue(channel?.channelId ?? '')} '
    'projected_room_id=${_logValue(channel?.roomId ?? '')} '
    'projected_status=${_logValue(channel?.memberStatus ?? '')} '
    'projected_type=${_logValue(channel?.channelType ?? '')} '
    'error=${_logValue(error == null ? '' : '$error')}',
  );
}

String _logValue(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '<empty>' : trimmed;
}
