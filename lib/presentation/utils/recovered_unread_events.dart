import 'package:matrix/matrix.dart';

import '../../data/as_client.dart';

List<Event> mergeRecoveredUnreadEvents({
  required Room room,
  required Iterable<Event> timelineEvents,
  required Iterable<AsUnreadMessage> recoveredMessages,
}) {
  final byEventId = <String, Event>{};
  for (final message in recoveredMessages) {
    if (message.eventId.isEmpty || byEventId.containsKey(message.eventId)) {
      continue;
    }
    byEventId[message.eventId] = Event(
      room: room,
      eventId: message.eventId,
      senderId: message.senderId,
      type: EventTypes.Message,
      originServerTs: message.timestamp ?? DateTime.now().toUtc(),
      content: {
        'msgtype': _matrixMessageType(message.messageType),
        'body': message.content,
      },
    );
  }
  for (final event in timelineEvents) {
    byEventId[event.eventId] = event;
  }
  final events = byEventId.values.toList();
  events.sort((a, b) => b.originServerTs.compareTo(a.originServerTs));
  return events;
}

String _matrixMessageType(String value) {
  return switch (value) {
    'text' || '' => MessageTypes.Text,
    _ => value,
  };
}
