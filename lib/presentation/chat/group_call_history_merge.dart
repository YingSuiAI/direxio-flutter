import 'package:matrix/matrix.dart';

import '../../data/as_call_session_store.dart';
import '../../data/as_client.dart';
import 'call_timeline_events.dart';

List<AsCallSession> asCallSessionsForGroupTimeline({
  required Iterable<AsCallSession> sessions,
  required String roomId,
  required Iterable<Event> rawTimelineEvents,
  required Iterable<Event> visibleEvents,
  required Iterable<Event> callRecordContextEvents,
}) {
  final trimmedRoomId = roomId.trim();
  if (trimmedRoomId.isEmpty) return const [];
  final rawCallIds =
      _callIdsForEvents(rawTimelineEvents, callRecordContextEvents);
  final visibleCallIds =
      _callIdsForEvents(visibleEvents, callRecordContextEvents);
  final selected = <AsCallSession>[];
  for (final session in sessions) {
    final callId = session.callId.trim();
    if (callId.isEmpty ||
        session.roomId.trim() != trimmedRoomId ||
        !asCallSessionSnapshotIsTerminal(session)) {
      continue;
    }
    if (visibleCallIds.contains(callId) || !rawCallIds.contains(callId)) {
      selected.add(session);
    }
  }
  selected.sort(
    (a, b) => asCallSessionStableTimestamp(b).compareTo(
      asCallSessionStableTimestamp(a),
    ),
  );
  return selected;
}

List<Event> groupTimelineEventsReplacingAsCallSnapshots({
  required Iterable<Event> visibleEvents,
  required Iterable<Event> callRecordContextEvents,
  required Iterable<AsCallSession> asCallSessions,
}) {
  final asCallIds = {
    for (final session in asCallSessions)
      if (session.callId.trim().isNotEmpty) session.callId.trim(),
  };
  if (asCallIds.isEmpty) return visibleEvents.toList(growable: false);
  return [
    for (final event in visibleEvents)
      if (!_eventHasAsSnapshot(
        event,
        callRecordContextEvents,
        asCallIds,
      ))
        event,
  ];
}

bool shouldReloadAsCallSessionsForGroupTimeline({
  required Iterable<Event> visibleEvents,
  required Iterable<Event> callRecordContextEvents,
  required Iterable<AsCallSession> currentSessions,
}) {
  final terminalCallIds = {
    for (final session in currentSessions)
      if (asCallSessionSnapshotIsTerminal(session) &&
          session.callId.trim().isNotEmpty)
        session.callId.trim(),
  };
  for (final event in visibleEvents) {
    if (!isProductGroupCallEvent(event)) continue;
    final callId = asCallIdForCallRecord(event, callRecordContextEvents);
    if (callId == null || callId.trim().isEmpty) continue;
    if (!terminalCallIds.contains(callId.trim())) return true;
  }
  return false;
}

DateTime asCallSessionStableTimestamp(AsCallSession session) {
  return session.endedAt ?? session.answeredAt ?? session.createdAt;
}

Set<String> _callIdsForEvents(
  Iterable<Event> events,
  Iterable<Event> callRecordContextEvents,
) {
  final ids = <String>{};
  for (final event in events) {
    if (!isCallRecordEvent(event)) continue;
    final callId = asCallIdForCallRecord(event, callRecordContextEvents);
    if (callId != null && callId.trim().isNotEmpty) {
      ids.add(callId.trim());
    }
  }
  return ids;
}

bool _eventHasAsSnapshot(
  Event event,
  Iterable<Event> callRecordContextEvents,
  Set<String> asCallIds,
) {
  if (!isCallRecordEvent(event)) return false;
  final callId = asCallIdForCallRecord(event, callRecordContextEvents);
  return callId != null && asCallIds.contains(callId.trim());
}
