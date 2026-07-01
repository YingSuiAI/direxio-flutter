import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/presentation/notifications/grouped_push_notification.dart';
import 'package:portal_app/presentation/utils/push_notification_navigation.dart';

void main() {
  test('parses collapse id and unread count', () {
    final payload = PushNotificationPayload.fromData({
      'room_id': '!room:example.org',
      'collapse_id': 'room-1',
      'unread_count': '4',
    });

    expect(payload, isNotNull);
    expect(payload!.collapseId, 'room-1');
    expect(payload.unreadCount, 4);
  });

  test('same room stable notification id and incremented count', () {
    final store = GroupedPushNotificationStore();

    final first = store.apply({
      'room_id': '!room:example.org',
      'room_name': 'General',
      'event_id': r'$event-1',
    });
    final second = store.apply({
      'room_id': '!room:example.org',
      'room_name': 'General',
      'event_id': r'$event-2',
    });

    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(second!.notificationId, first!.notificationId);
    expect(second.count, 2);
    expect(first.body, pushNotificationBodyText);
    expect(second.body, '2 条新消息');
  });

  test('server unread count wins', () {
    final store = GroupedPushNotificationStore();

    store.apply({
      'room_id': '!room:example.org',
      'event_id': r'$event-1',
    });
    final grouped = store.apply({
      'room_id': '!room:example.org',
      'event_id': r'$event-2',
      'unread': 7,
    });

    expect(grouped, isNotNull);
    expect(grouped!.count, 7);
    expect(grouped.body, '7 条新消息');
  });

  test('different rooms get different ids', () {
    expect(
      notificationIdForRoom('!room-a:example.org'),
      isNot(notificationIdForRoom('!room-b:example.org')),
    );
  });

  test('post and call pushes are ignored', () {
    final store = GroupedPushNotificationStore();

    expect(
      store.apply({
        'room_id': '!room:example.org',
        'push_type': 'post',
      }),
      isNull,
    );
    expect(
      store.apply({
        'room_id': '!room:example.org',
        'push_type': 'call',
      }),
      isNull,
    );
  });

  test('payload JSON preserves route data', () {
    final store = GroupedPushNotificationStore();

    final grouped = store.apply({
      'room_id': '!room:example.org',
      'room_type': 'group',
      'room_name': 'General',
      'event_id': r'$event-1',
      'collapseId': 'collapse-1',
    });

    expect(grouped, isNotNull);
    expect(grouped!.title, 'General');
    expect(jsonDecode(grouped.payloadJson), {
      'room_id': '!room:example.org',
      'room_type': 'group',
      'room_name': 'General',
      'event_id': r'$event-1',
      'collapseId': 'collapse-1',
    });
  });

  test('clearRoom resets local count for a room', () {
    final store = GroupedPushNotificationStore();

    store.apply({'room_id': '!room:example.org'});
    store.apply({'room_id': '!room:example.org'});
    store.clearRoom('!room:example.org');
    final grouped = store.apply({'room_id': '!room:example.org'});

    expect(grouped, isNotNull);
    expect(grouped!.count, 1);
    expect(grouped.body, pushNotificationBodyText);
  });

  test('snapshot is immutable copy and includes current counts', () {
    final store = GroupedPushNotificationStore();

    store.apply({'room_id': '!room-a:example.org'});
    store.apply({'room_id': '!room-a:example.org'});
    store.apply({'room_id': '!room-b:example.org'});
    final snapshot = store.snapshot;

    expect(snapshot, {
      '!room-a:example.org': 2,
      '!room-b:example.org': 1,
    });
    expect(
      () => snapshot['!room-a:example.org'] = 99,
      throwsUnsupportedError,
    );
    expect(store.snapshot['!room-a:example.org'], 2);
  });

  test('initialCounts are honored', () {
    final store = GroupedPushNotificationStore({'!room:example.org': 4});

    final grouped = store.apply({'room_id': '!room:example.org'});

    expect(grouped, isNotNull);
    expect(grouped!.count, 5);
    expect(grouped.body, '5 条新消息');
  });

  test('fallback title is Direxio when no room name', () {
    final store = GroupedPushNotificationStore();

    final grouped = store.apply({'room_id': '!room:example.org'});

    expect(grouped, isNotNull);
    expect(grouped!.title, 'Direxio');
  });

  test('unread zero and negative values local-increment instead of displaying',
      () {
    final store = GroupedPushNotificationStore();

    final zero = store.apply({
      'room_id': '!room:example.org',
      'unread_count': 0,
    });
    final negative = store.apply({
      'room_id': '!room:example.org',
      'unread_count': -2,
    });

    expect(zero, isNotNull);
    expect(zero!.count, 1);
    expect(zero.body, pushNotificationBodyText);
    expect(negative, isNotNull);
    expect(negative!.count, 2);
    expect(negative.body, '2 条新消息');
  });
}
