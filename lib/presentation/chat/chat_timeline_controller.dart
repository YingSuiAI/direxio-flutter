import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';

import 'chat_history_backfill_policy.dart';
import '../utils/message_history_policy.dart';

class ChatTimelineController {
  const ChatTimelineController({
    required this.room,
    required this.rebuild,
    required this.debugLabel,
    this.initialTargetMessages = chatOpenLocalHistoryTargetMessages,
  });

  final Room room;
  final VoidCallback rebuild;
  final String debugLabel;
  final int initialTargetMessages;

  Future<Timeline?> openInitialTimeline({
    Future<void> Function(Timeline timeline)? syncEmptyRoomHistory,
  }) async {
    final Timeline timeline;
    try {
      timeline = await room.getTimeline(
        onUpdate: rebuild,
        onChange: (_) => rebuild(),
        onInsert: (_) => rebuild(),
        onRemove: (_) => rebuild(),
      );
    } on Object catch (e) {
      debugPrint('$debugLabel getTimeline failed: $e');
      return null;
    }

    if (syncEmptyRoomHistory != null) {
      await syncEmptyRoomHistory(timeline);
    }
    await backfillLocalStoredHistory(timeline);
    await requestInitialRemoteHistory(timeline);
    return timeline;
  }

  Future<void> backfillLocalStoredHistory(Timeline timeline) async {
    var attempts = 0;
    while (attempts < chatOpenLocalHistoryMaxAttempts) {
      if (!shouldBackfillLocalChatOpenHistory(
        timelineEvents: timeline.events,
        hasStoredOlderEvents: true,
      )) {
        break;
      }

      try {
        final database = timeline.room.client.database;
        if (database == null) break;
        final storedEvents = await database.getEventList(
          timeline.room,
          start: timeline.events.length,
          limit: chatOpenLocalHistoryPageSize,
        );
        if (storedEvents.isEmpty) break;
        await hydrateStoredEventSenders(timeline.room, storedEvents);
        timeline.events.addAll(storedEvents);
      } on Object catch (e) {
        debugPrint('$debugLabel local timeline backfill failed: $e');
        break;
      }
      attempts++;
    }
    rebuild();
  }

  Future<void> requestInitialRemoteHistory(Timeline timeline) async {
    if (!shouldRequestHistoricalMessages(MessageHistoryLoadTrigger.chatOpen)) {
      return;
    }
    var attempts = 0;
    while (attempts < chatOpenLocalHistoryMaxAttempts &&
        timeline.canRequestHistory &&
        visibleMessageCountForChatOpenHistory(timeline.events) <
            initialTargetMessages) {
      try {
        await timeline.requestHistory(
            historyCount: chatOpenLocalHistoryPageSize);
      } on Object catch (e) {
        debugPrint('$debugLabel timeline.requestHistory failed: $e');
        break;
      }
      attempts++;
    }
    rebuild();
  }

  Future<void> requestOlderMessages(Timeline timeline) async {
    if (!shouldRequestHistoricalMessages(
      MessageHistoryLoadTrigger.userLoadOlder,
    )) {
      return;
    }
    if (!timeline.canRequestHistory) return;
    try {
      await timeline.requestHistory(historyCount: chatOpenLocalHistoryPageSize);
      rebuild();
    } on Object catch (e) {
      debugPrint('$debugLabel timeline.requestHistory failed: $e');
    }
  }
}

Future<void> hydrateStoredEventSenders(
  Room room,
  Iterable<Event> events,
) async {
  final database = room.client.database;
  if (database == null) return;
  for (final event in events) {
    if (room.getState(EventTypes.RoomMember, event.senderId) != null) {
      continue;
    }
    final user = await database.getUser(event.senderId, room);
    if (user != null) room.setState(user);
  }
}
