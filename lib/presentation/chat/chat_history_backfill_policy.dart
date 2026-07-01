import 'package:matrix/matrix.dart';

import 'call_timeline_events.dart';

const chatOpenLocalHistoryTargetMessages = 20;
const chatOpenLocalHistoryPageSize = 20;
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
