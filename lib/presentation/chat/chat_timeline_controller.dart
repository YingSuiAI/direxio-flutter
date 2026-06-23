import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';

import '../../data/as_client.dart';
import '../../data/matrix_room_history_sync.dart';
import 'chat_history_backfill_policy.dart';
import '../utils/read_marker_sync.dart';
import '../utils/message_history_policy.dart';
import '../utils/room_read_state.dart';

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

  bool get _canUseMatrixNetwork =>
      room.client.isLogged() && room.client.homeserver != null;

  Future<Timeline?> openInitialTimeline() async {
    final timeline = await _openTimeline();
    if (timeline == null) return null;
    unawaited(hydrateInitialTimeline(timeline));
    return timeline;
  }

  Future<Timeline?> openLocalTimelineForPrewarm() async {
    final timeline = await _openTimeline();
    if (timeline == null) return null;
    await backfillLocalStoredHistory(timeline);
    return timeline;
  }

  Future<Timeline?> _openTimeline() async {
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
    return timeline;
  }

  Future<void> hydrateInitialTimeline(Timeline timeline) async {
    await backfillLocalStoredHistory(timeline);
    await requestInitialRemoteHistory(timeline);
  }

  Future<void> syncEmptyRoomHistoryIfNeeded(Timeline timeline) async {
    if (!_canUseMatrixNetwork) return;
    if (!shouldSyncEmptyRoomHistoryOnOpen(
      timelineEvents: timeline.events,
      prevBatch: timeline.room.prev_batch,
    )) {
      return;
    }
    try {
      await syncMatrixRoomHistory(
        timeline.room.client,
        roomId: timeline.room.id,
        timelineLimit: chatOpenLocalHistoryPageSize,
      );
    } on Object catch (e) {
      debugPrint('$debugLabel empty room history sync failed: $e');
    }
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
    if (!_canUseMatrixNetwork) return;
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
    if (!_canUseMatrixNetwork) return;
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

  Future<bool> markCurrentTimelineRead({
    required Timeline? timeline,
    required AsClient asClient,
    required void Function(DateTime readAt) onUnreadCleared,
  }) async {
    final markerEvent =
        timeline == null ? null : latestSyncedMessageEvent(timeline);
    final readAt = markerEvent?.originServerTs ?? DateTime.now().toUtc();
    final changed = markRoomLocallyRead(room);
    onUnreadCleared(readAt);

    if (timeline == null) return changed;
    try {
      await timeline.setReadMarker(eventId: markerEvent?.eventId);
      if (markerEvent != null) {
        unawaited(updateAsReadMarkerForEvent(
          asClient: asClient,
          room: room,
          event: markerEvent,
        ).then((_) => onUnreadCleared(markerEvent.originServerTs)).catchError(
          (Object e) {
            debugPrint('$debugLabel P2P read marker sync failed: $e');
          },
        ));
      }
    } on Object catch (e) {
      debugPrint('$debugLabel setReadMarker failed: $e');
    }
    return changed;
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
