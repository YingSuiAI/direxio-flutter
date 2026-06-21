import 'package:matrix/matrix.dart';

import 'call_timeline_events.dart';

const chatOpenLocalHistoryTargetMessages = 50;
const chatOpenLocalHistoryPageSize = 30;
const chatOpenLocalHistoryMaxAttempts = 5;

int visibleMessageCountForChatOpenHistory(Iterable<Event> events) {
  return chatDisplayEventsForTimeline(events)
      .where((event) => event.type == EventTypes.Message)
      .length;
}

bool shouldBackfillLocalChatOpenHistory({
  required Iterable<Event> timelineEvents,
  required bool hasStoredOlderEvents,
}) {
  if (!hasStoredOlderEvents) return false;
  return visibleMessageCountForChatOpenHistory(timelineEvents) <
      chatOpenLocalHistoryTargetMessages;
}

bool shouldSyncEmptyRoomHistoryOnOpen({
  required Iterable<Event> timelineEvents,
  required String? prevBatch,
}) {
  if (visibleMessageCountForChatOpenHistory(timelineEvents) > 0) {
    return false;
  }
  return (prevBatch ?? '').isEmpty;
}
