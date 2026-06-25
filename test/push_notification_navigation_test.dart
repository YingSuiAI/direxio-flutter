import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/utils/push_notification_navigation.dart';

void main() {
  test('uses the fixed notification body copy', () {
    expect(pushNotificationBodyText, 'Send you a new message');
  });

  test('routes direct message pushes to the direct chat room', () {
    expect(
      pushNotificationRouteForData({
        'room_id': '!alice:p2p-im.com',
        'event_id': r'$event1',
        'room_type': 'direct',
        'push_type': 'message',
      }),
      '/chat/!alice%3Ap2p-im.com?event=%24event1',
    );
  });

  test('routes group message pushes to the group chat room', () {
    expect(
      pushNotificationRouteForData({
        'room_id': '!group:p2p-im.com',
        'event_id': r'$event2',
        'room_type': 'group',
      }),
      '/group/!group%3Ap2p-im.com?event=%24event2',
    );
  });

  test('routes text channel message pushes to the channel conversation', () {
    expect(
      pushNotificationRouteForData({
        'room_id': '!channel:p2p-im.com',
        'room_type': 'channel',
        'channel_id': 'ch_text',
        'room_name': 'Announcements',
      }),
      '/channel/ch_text/conversation?name=Announcements',
    );
  });

  test('does not route channel post pushes', () {
    expect(
      pushNotificationRouteForData({
        'room_id': '!channel:p2p-im.com',
        'room_type': 'channel_post',
        'push_type': 'post',
      }),
      isNull,
    );
  });

  test('does not route gateway-suppressed channel post pushes', () {
    expect(
      pushNotificationRouteForData({
        'room_id': '!channel:p2p-im.com',
        'room_type': 'channel',
        'push_type': 'message',
        'channel_kind': 'post',
      }),
      isNull,
    );
    expect(
      pushNotificationRouteForData({
        'room_id': '!channel:p2p-im.com',
        'room_type': 'channel',
        'suppress_push': 'true',
      }),
      isNull,
    );
  });

  test('uses notification title as an optional channel route name', () {
    expect(
      pushNotificationRouteForData({
        'room_id': '!channel:p2p-im.com',
        'room_type': 'channel',
        'notification_title': 'Text Channel',
      }),
      '/channel/!channel%3Ap2p-im.com/conversation?name=Text%20Channel',
    );
  });

  test('routes direct voice call pushes to the call page', () {
    expect(
      pushNotificationRouteForData({
        'room_id': '!alice:p2p-im.com',
        'room_type': 'direct',
        'push_type': 'call',
        'call_id': 'call-1',
        'call_kind': 'voice',
      }),
      '/call/!alice%3Ap2p-im.com?call_id=call-1&incoming=1',
    );
  });

  test('routes group video call pushes to the group video call page', () {
    expect(
      pushNotificationRouteForData({
        'room_id': '!group:p2p-im.com',
        'room_type': 'group',
        'push_type': 'call',
        'call_id': 'call-2',
        'call_kind': 'video',
        'room_name': 'Team',
      }),
      '/group-video-call/!group%3Ap2p-im.com'
      '?name=Team&call_id=call-2&incoming=1',
    );
  });

  test('uses bootstrap metadata when the push payload omits room type', () {
    final context = pushNotificationRouteContextFromBootstrap(
      AsSyncBootstrap(
        syncedAt: DateTime.utc(2026, 6, 25),
        user: const AsSyncUser(
          userId: '@me:p2p-im.com',
        ),
        rooms: const [],
        contacts: const [],
        groups: const [],
        channels: const [
          AsSyncRoomSummary(
            channelId: 'ch_cached',
            roomId: '!channel:p2p-im.com',
            name: 'Cached Channel',
            avatarUrl: '',
            unreadCount: 0,
            lastActivityAt: null,
          ),
        ],
        pending: const AsSyncPending.empty(),
      ),
      '!channel:p2p-im.com',
    );

    expect(
      pushNotificationRouteForData(
        {'room_id': '!channel:p2p-im.com'},
        context: context,
      ),
      '/channel/ch_cached/conversation?name=Cached%20Channel',
    );
  });
}
