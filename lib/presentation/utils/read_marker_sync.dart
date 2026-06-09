import 'package:matrix/matrix.dart';

import '../../data/as_client.dart';

Event? latestSyncedMessageEvent(Timeline timeline) {
  Event? latest;
  for (final event in timeline.events) {
    if (event.status.isSynced && event.type == EventTypes.Message) {
      if (latest == null ||
          event.originServerTs.isAfter(latest.originServerTs)) {
        latest = event;
      }
    }
  }
  return latest;
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
