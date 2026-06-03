import 'package:matrix/matrix.dart';

Iterable<String> thumbnailEventIdsForEvents(
  Iterable<Event> events, {
  int limit = 40,
}) sync* {
  if (limit <= 0) return;
  final seen = <String>{};
  for (final event in events) {
    if (event.type != EventTypes.Message ||
        event.messageType != MessageTypes.Image) {
      continue;
    }
    final eventId = event.eventId.trim();
    if (eventId.isEmpty || seen.contains(eventId)) continue;
    seen.add(eventId);
    yield eventId;
    if (seen.length >= limit) return;
  }
}
