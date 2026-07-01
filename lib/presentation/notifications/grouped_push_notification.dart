import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../utils/push_notification_navigation.dart';

const direxioLocalPushChannelId = 'direxio_messages';
const direxioLocalPushChannelName = 'Direxio messages';
const direxioLocalPushChannelDescription = 'Direxio message notifications';

class GroupedPushNotification {
  const GroupedPushNotification({
    required this.notificationId,
    required this.roomId,
    required this.count,
    required this.title,
    required this.body,
    required this.payloadJson,
    this.collapseId,
  });

  final int notificationId;
  final String roomId;
  final int count;
  final String title;
  final String body;
  final String payloadJson;
  final String? collapseId;
}

class GroupedPushNotificationStore {
  GroupedPushNotificationStore([Map<String, int>? initialCounts])
      : _countsByRoomId = {...?initialCounts};

  final Map<String, int> _countsByRoomId;

  Map<String, int> get snapshot => Map.unmodifiable(_countsByRoomId);

  void clearRoom(String roomId) {
    _countsByRoomId.remove(roomId.trim());
  }

  GroupedPushNotification? apply(Map<String, dynamic> data) {
    final payload = PushNotificationPayload.fromData(data);
    if (payload == null || payload.isPost || payload.isCall) return null;

    final serverUnreadCount = payload.unreadCount;
    final count = serverUnreadCount != null && serverUnreadCount > 0
        ? serverUnreadCount
        : (_countsByRoomId[payload.roomId] ?? 0) + 1;
    _countsByRoomId[payload.roomId] = count;

    return GroupedPushNotification(
      notificationId: notificationIdForRoom(payload.roomId),
      roomId: payload.roomId,
      count: count,
      title: payload.roomName ?? 'Direxio',
      body: count == 1 ? pushNotificationBodyText : '$count 条新消息',
      payloadJson: jsonEncode(data),
      collapseId: payload.collapseId,
    );
  }
}

int notificationIdForRoom(String roomId) {
  final digest = sha1.convert(utf8.encode(roomId.trim()));
  final bytes = digest.bytes;
  return ((bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3]) &
      0x7fffffff;
}
