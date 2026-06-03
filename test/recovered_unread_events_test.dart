import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/utils/recovered_unread_events.dart';

void main() {
  test('mergeRecoveredUnreadEvents dedupes and sorts newest first', () {
    final client = Client('PortalIMRecoveredUnreadTest')
      ..setUserId('@owner:example.com');
    final room = Room(
      id: '!room:example.com',
      client: client,
      membership: Membership.join,
    );
    final timelineEvent = Event(
      room: room,
      eventId: r'$existing',
      senderId: '@alice:example.com',
      type: EventTypes.Message,
      originServerTs: DateTime.parse('2026-05-25T10:00:00Z'),
      content: {
        'msgtype': MessageTypes.Text,
        'body': 'already local',
      },
    );

    final merged = mergeRecoveredUnreadEvents(
      room: room,
      timelineEvents: [timelineEvent],
      recoveredMessages: [
        AsUnreadMessage(
          eventId: r'$newer',
          senderId: '@bob:example.com',
          senderName: 'Bob',
          content: 'from AS unread recovery',
          messageType: MessageTypes.Text,
          timestamp: DateTime.parse('2026-05-25T10:01:00Z'),
        ),
        AsUnreadMessage(
          eventId: r'$existing',
          senderId: '@alice:example.com',
          senderName: 'Alice',
          content: 'duplicate',
          messageType: MessageTypes.Text,
          timestamp: DateTime.parse('2026-05-25T10:00:00Z'),
        ),
      ],
    );

    expect(merged.map((e) => e.eventId), [r'$newer', r'$existing']);
    expect(merged.first.plaintextBody, 'from AS unread recovery');
  });
}
