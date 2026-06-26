import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/presentation/chat/chat_timeline_event_source.dart';

void main() {
  test('includes room last event when timeline has not hydrated it', () {
    final client = Client('DirexioTimelineLastEventSourceTest')
      ..setUserId('@owner:p2p-im.com');
    final room = Room(
      id: '!room:p2p-im.com',
      client: client,
      membership: Membership.join,
    );
    final lastEvent = _messageEvent(
      room,
      eventId: r'$latest',
      body: 'latest message',
      at: DateTime.utc(2026, 6, 26, 10, 1),
    );
    room.lastEvent = lastEvent;

    final events = timelineEventsIncludingRoomLastEvent(room, null);

    expect(events, [lastEvent]);
  });

  test('does not duplicate room last event already in timeline', () async {
    final client = Client('DirexioTimelineLastEventDedupTest')
      ..setUserId('@owner:p2p-im.com');
    final room = Room(
      id: '!room:p2p-im.com',
      client: client,
      membership: Membership.join,
    );
    client.rooms.add(room);
    final lastEvent = _messageEvent(
      room,
      eventId: r'$latest',
      body: 'latest message',
      at: DateTime.utc(2026, 6, 26, 10, 1),
    );
    room.lastEvent = lastEvent;
    final timeline = await room.getTimeline();
    timeline.events.add(lastEvent);

    final events = timelineEventsIncludingRoomLastEvent(room, timeline);

    expect(events, [lastEvent]);
  });
}

Event _messageEvent(
  Room room, {
  required String eventId,
  required String body,
  required DateTime at,
}) {
  return Event(
    room: room,
    eventId: eventId,
    senderId: '@alice:p2p-im.com',
    type: EventTypes.Message,
    originServerTs: at,
    content: {
      'msgtype': MessageTypes.Text,
      'body': body,
    },
  );
}
