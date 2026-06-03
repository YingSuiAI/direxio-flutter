import 'package:matrix/matrix.dart';

import '../../data/as_client.dart';

Event? latestSyncedMessageEvent(Timeline timeline) {
  for (final event in timeline.events) {
    if (event.status.isSynced && event.type == EventTypes.Message) {
      return event;
    }
  }
  return null;
}

Event? latestCallHangupEventForCall({
  required Room room,
  required String callId,
}) {
  final lastEvent = room.lastEvent;
  if (lastEvent != null &&
      lastEvent.status.isSynced &&
      lastEvent.type == EventTypes.CallHangup &&
      lastEvent.content['call_id'] == callId &&
      lastEvent.eventId.isNotEmpty) {
    return lastEvent;
  }
  return null;
}

Future<void> updateAsReadMarkerForEvent({
  required AsClient asClient,
  required Room room,
  required Event event,
}) {
  return asClient.updateReadMarker(
    room.id,
    event.eventId,
    event.originServerTs,
  );
}
