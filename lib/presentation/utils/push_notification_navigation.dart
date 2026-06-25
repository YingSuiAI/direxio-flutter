import '../../data/as_client.dart';
import 'direct_contact_status.dart';

const pushNotificationBodyText = 'Send you a new message';

class PushNotificationRouteContext {
  const PushNotificationRouteContext({
    this.roomType,
    this.channelId,
    this.roomName,
  });

  final String? roomType;
  final String? channelId;
  final String? roomName;
}

String? pushNotificationRouteForData(
  Map<String, dynamic> data, {
  PushNotificationRouteContext context = const PushNotificationRouteContext(),
}) {
  final payload = PushNotificationPayload.fromData(data);
  if (payload == null || payload.isPost) return null;

  final roomType = _normalizeRoomType(
    payload.roomType ?? context.roomType,
  );
  final encodedRoomId = Uri.encodeComponent(payload.roomId);

  if (payload.isCall) {
    final query = _queryString({
      'name': payload.roomName ?? context.roomName,
      'call_id': payload.callId,
      'incoming': '1',
    });
    if (roomType == asConversationKindGroup) {
      final prefix = payload.isVideoCall ? '/group-video-call' : '/group-call';
      return '$prefix/$encodedRoomId$query';
    }
    final prefix = payload.isVideoCall ? '/video-call' : '/call';
    return '$prefix/$encodedRoomId$query';
  }

  if (roomType == asConversationKindChannel) {
    final channelId =
        (payload.channelId ?? context.channelId ?? payload.roomId).trim();
    if (channelId.isEmpty) return null;
    final query = _queryString({'name': payload.roomName ?? context.roomName});
    return '/channel/${Uri.encodeComponent(channelId)}/conversation$query';
  }
  if (roomType == asConversationKindGroup) {
    return '/group/$encodedRoomId${_queryString({'event': payload.eventId})}';
  }
  return '/chat/$encodedRoomId${_queryString({'event': payload.eventId})}';
}

PushNotificationRouteContext pushNotificationRouteContextFromBootstrap(
  AsSyncBootstrap? bootstrap,
  String roomId,
) {
  final trimmed = roomId.trim();
  if (trimmed.isEmpty || bootstrap == null) {
    return const PushNotificationRouteContext();
  }
  for (final channel in bootstrap.channels) {
    if (channel.roomId.trim() == trimmed) {
      return PushNotificationRouteContext(
        roomType: asConversationKindChannel,
        channelId: channel.channelId,
        roomName: channel.name,
      );
    }
  }
  for (final group in bootstrap.groups) {
    if (group.roomId.trim() == trimmed) {
      return PushNotificationRouteContext(
        roomType: asConversationKindGroup,
        roomName: group.name,
      );
    }
  }
  for (final contact in bootstrap.contacts) {
    if (contact.roomId.trim() == trimmed) {
      return PushNotificationRouteContext(
        roomType: asConversationKindDirect,
        roomName: contact.displayName,
      );
    }
  }
  return const PushNotificationRouteContext();
}

String? pushNotificationRoomIdFromData(Map<String, dynamic> data) {
  return PushNotificationPayload.fromData(data)?.roomId;
}

String? pushNotificationRouteRoomTypeFromNativeProfile(
  Map<String, dynamic>? content,
) {
  final roomType = _stringValue(content?['room_type']);
  return _normalizeRoomType(roomType);
}

class PushNotificationPayload {
  const PushNotificationPayload({
    required this.roomId,
    this.eventId,
    this.pushType,
    this.roomType,
    this.callId,
    this.callKind,
    this.channelId,
    this.roomName,
    this.channelKind,
    this.suppressPushValue,
  });

  final String roomId;
  final String? eventId;
  final String? pushType;
  final String? roomType;
  final String? callId;
  final String? callKind;
  final String? channelId;
  final String? roomName;
  final String? channelKind;
  final String? suppressPushValue;

  bool get isCall {
    final type = pushType?.toLowerCase();
    final kind = callKind?.toLowerCase();
    return type == 'call' ||
        type == 'voice_call' ||
        type == 'video_call' ||
        kind == 'voice' ||
        kind == 'video';
  }

  bool get isVideoCall {
    final type = pushType?.toLowerCase();
    final kind = callKind?.toLowerCase();
    return type == 'video_call' || kind == 'video';
  }

  bool get isPost {
    final type = pushType?.toLowerCase();
    final normalizedRoomType = roomType?.toLowerCase();
    return type == 'post' ||
        type == 'channel_post' ||
        channelKind?.toLowerCase() == 'post' ||
        suppressPush ||
        normalizedRoomType == 'post' ||
        normalizedRoomType == 'channel_post';
  }

  bool get suppressPush {
    final value = suppressPushValue?.toLowerCase();
    return value == 'true' || value == '1' || value == 'yes';
  }

  static PushNotificationPayload? fromData(Map<String, dynamic> data) {
    final roomId = _firstString(data, const [
      'room_id',
      'roomId',
      'room',
      'matrix_room_id',
    ]);
    if (roomId == null) return null;
    return PushNotificationPayload(
      roomId: roomId,
      eventId: _firstString(data, const ['event_id', 'eventId']),
      pushType: _firstString(data, const ['push_type', 'pushType', 'type']),
      roomType: _firstString(data, const ['room_type', 'roomType']),
      callId: _firstString(data, const ['call_id', 'callId']),
      callKind: _firstString(data, const [
        'call_kind',
        'callKind',
        'call_type',
        'callType',
      ]),
      channelId: _firstString(data, const ['channel_id', 'channelId']),
      roomName: _firstString(data, const [
        'room_name',
        'roomName',
        'conversation_name',
        'conversationName',
        'notification_title',
        'notificationTitle',
        'title',
        'name',
      ]),
      channelKind: _firstString(data, const ['channel_kind', 'channelKind']),
      suppressPushValue: _firstString(data, const [
        'suppress_push',
        'suppressPush',
      ]),
    );
  }
}

String _queryString(Map<String, String?> values) {
  final parts = <String>[];
  for (final entry in values.entries) {
    final value = entry.value?.trim() ?? '';
    if (value.isEmpty) continue;
    parts.add('${entry.key}=${Uri.encodeComponent(value)}');
  }
  if (parts.isEmpty) return '';
  return '?${parts.join('&')}';
}

String? _normalizeRoomType(String? value) {
  final normalized = value?.trim().toLowerCase() ?? '';
  return switch (normalized) {
    asConversationKindDirect ||
    nativeDirectRoomType =>
      asConversationKindDirect,
    asConversationKindGroup || nativeGroupRoomType => asConversationKindGroup,
    asConversationKindChannel ||
    nativeChannelRoomType =>
      asConversationKindChannel,
    asConversationKindAgent => asConversationKindAgent,
    _ => null,
  };
}

String? _firstString(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = _stringValue(data[key]);
    if (value != null) return value;
  }
  return null;
}

String? _stringValue(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}
