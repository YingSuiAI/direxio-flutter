import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';

import '../../data/as_client.dart';
import 'chat_history_backfill_policy.dart';
import '../utils/read_marker_sync.dart';
import '../utils/room_read_state.dart';

typedef ChatReadMarkerSync = Future<void> Function({
  required Room room,
  required Event event,
});

typedef ChatTimelineLocalHistoryLoader = Future<List<Event>> Function(
  Timeline timeline, {
  required int start,
  required int limit,
});

class ChatTimelineController {
  const ChatTimelineController({
    required this.room,
    required this.rebuild,
    required this.debugLabel,
    this.localHistoryLoader,
  });

  final Room room;
  final VoidCallback rebuild;
  final String debugLabel;
  final ChatTimelineLocalHistoryLoader? localHistoryLoader;

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
        final storedEvents = await _loadLocalStoredEvents(
          timeline,
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

  Future<List<Event>> _loadLocalStoredEvents(
    Timeline timeline, {
    required int start,
    required int limit,
  }) async {
    final loader = localHistoryLoader;
    if (loader != null) {
      return loader(timeline, start: start, limit: limit);
    }
    final database = timeline.room.client.database;
    if (database == null) return const <Event>[];
    return database.getEventList(
      timeline.room,
      start: start,
      limit: limit,
    );
  }

  Future<void> requestOlderMessages(Timeline timeline) async {
    try {
      final storedEvents = await _loadLocalStoredEvents(
        timeline,
        start: timeline.events.length,
        limit: chatOpenLocalHistoryPageSize,
      );
      if (storedEvents.isNotEmpty) {
        await hydrateStoredEventSenders(timeline.room, storedEvents);
        timeline.events.addAll(storedEvents);
      }
    } on Object catch (e) {
      debugPrint('$debugLabel local timeline older load failed: $e');
    }
    rebuild();
  }

  Future<bool> markCurrentTimelineRead({
    required Timeline? timeline,
    required AsClient asClient,
    required void Function(DateTime readAt) onUnreadCleared,
    ChatReadMarkerSync? syncReadMarker,
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
        final sync = syncReadMarker ??
            ({required Room room, required Event event}) =>
                updateAsReadMarkerForEvent(
                  asClient: asClient,
                  room: room,
                  event: event,
                );
        unawaited(sync(
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
