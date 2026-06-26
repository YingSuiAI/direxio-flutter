import 'package:matrix/matrix.dart';

List<Event> timelineEventsIncludingRoomLastEvent(
  Room room,
  Timeline? timeline,
) {
  final events = timeline?.events ?? const <Event>[];
  final lastEvent = room.lastEvent;
  if (lastEvent == null) return events;
  final lastEventId = lastEvent.eventId.trim();
  if (lastEventId.isEmpty) return [lastEvent, ...events];
  for (final event in events) {
    if (event.eventId.trim() == lastEventId) return events;
  }
  return [lastEvent, ...events];
}
