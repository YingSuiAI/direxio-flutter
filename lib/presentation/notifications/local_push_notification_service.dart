import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../utils/push_notification_navigation.dart';
import 'grouped_push_notification.dart';

typedef LocalPushOpenHandler = FutureOr<void> Function(
  Map<String, dynamic> data,
);

@pragma('vm:entry-point')
void localPushNotificationBackgroundTap(NotificationResponse response) {
  LocalPushNotificationService.instance._handleNotificationResponse(
    response,
    callOpenHandler: false,
  );
}

class LocalPushNotificationService {
  LocalPushNotificationService._({
    FlutterLocalNotificationsPlugin? plugin,
    GroupedPushNotificationStore? store,
  })  : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _store = store ?? GroupedPushNotificationStore();

  static final LocalPushNotificationService instance =
      LocalPushNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin;
  final GroupedPushNotificationStore _store;

  LocalPushOpenHandler? _onOpen;
  bool _initialized = false;
  Future<void>? _initializing;

  Future<void> initialize({LocalPushOpenHandler? onOpen}) async {
    _onOpen = onOpen;
    if (_initialized) return;
    final initializing = _initializing;
    if (initializing != null) {
      await initializing;
      return;
    }

    final initialize = _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(),
        macOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          localPushNotificationBackgroundTap,
    );
    _initializing = initialize;
    try {
      await initialize;
      _initialized = true;
    } finally {
      _initializing = null;
    }
  }

  Future<void> showRemoteData(Map<String, dynamic> data) async {
    final notification = _store.apply(data);
    if (notification == null) return;

    await _plugin.show(
      id: notification.notificationId,
      title: notification.title,
      body: notification.body,
      notificationDetails: _notificationDetails(notification),
      payload: notification.payloadJson,
    );
  }

  Future<void> clearRoom(String roomId) async {
    _store.clearRoom(roomId);
    await _plugin.cancel(id: notificationIdForRoom(roomId));
  }

  Future<Map<String, dynamic>?> takeLaunchNotificationData() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;

    final data = _decodePayload(details?.notificationResponse?.payload);
    if (data == null) return null;

    await _clearRoomForData(data);
    return data;
  }

  void _handleNotificationResponse(
    NotificationResponse response, {
    bool callOpenHandler = true,
  }) {
    final data = _decodePayload(response.payload);
    if (data == null) return;

    unawaited(_clearRoomForData(data));

    final onOpen = _onOpen;
    if (callOpenHandler && onOpen != null) {
      unawaited(Future<void>.sync(() => onOpen(data)));
    }
  }

  Future<void> _clearRoomForData(Map<String, dynamic> data) async {
    final roomId = pushNotificationRoomIdFromData(data);
    if (roomId == null) return;
    try {
      await clearRoom(roomId);
    } catch (error) {
      debugPrint('[push-notification] local clear failed: $error');
    }
  }

  NotificationDetails _notificationDetails(
    GroupedPushNotification notification,
  ) {
    final threadIdentifier = notification.collapseId ?? notification.roomId;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        direxioLocalPushChannelId,
        direxioLocalPushChannelName,
        channelDescription: direxioLocalPushChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.message,
        groupKey: notification.roomId,
        number: notification.count,
      ),
      iOS: DarwinNotificationDetails(
        threadIdentifier: threadIdentifier,
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      macOS: DarwinNotificationDetails(
        threadIdentifier: threadIdentifier,
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  Map<String, dynamic>? _decodePayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return null;
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    } on FormatException {
      return null;
    }
  }
}
