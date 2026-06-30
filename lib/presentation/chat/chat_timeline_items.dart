class ChatTimelineItem<TEvent, TOutbox> {
  const ChatTimelineItem._({
    required this.timestamp,
    required int sourceOrder,
    TEvent? event,
    TOutbox? outbox,
  })  : _event = event,
        _outbox = outbox,
        _sourceOrder = sourceOrder;

  factory ChatTimelineItem.event({
    required TEvent event,
    required DateTime timestamp,
    required int sourceOrder,
  }) {
    return ChatTimelineItem._(
      event: event,
      timestamp: timestamp,
      sourceOrder: sourceOrder,
    );
  }

  factory ChatTimelineItem.outbox({
    required TOutbox outbox,
    required DateTime timestamp,
    required int sourceOrder,
  }) {
    return ChatTimelineItem._(
      outbox: outbox,
      timestamp: timestamp,
      sourceOrder: sourceOrder,
    );
  }

  final DateTime timestamp;
  final int _sourceOrder;
  final TEvent? _event;
  final TOutbox? _outbox;

  TOutbox? get outboxOrNull => _outbox;

  TResult when<TResult>({
    required TResult Function(TEvent event) event,
    required TResult Function(TOutbox outbox) outbox,
  }) {
    final eventValue = _event;
    if (eventValue != null) return event(eventValue);
    final outboxValue = _outbox;
    if (outboxValue != null) return outbox(outboxValue);
    throw StateError('ChatTimelineItem contains neither event nor outbox');
  }
}

List<ChatTimelineItem<TEvent, TOutbox>>
    mergeChatTimelineItems<TEvent, TOutbox>({
  required List<TEvent> events,
  required DateTime Function(TEvent event) eventTimestamp,
  DateTime? Function(TEvent event)? eventSortTimestamp,
  required List<TOutbox> outboxItems,
  required DateTime Function(TOutbox outbox) outboxTimestamp,
}) {
  final items = <ChatTimelineItem<TEvent, TOutbox>>[];
  var sourceOrder = 0;
  for (final event in events) {
    items.add(
      ChatTimelineItem.event(
        event: event,
        timestamp: eventSortTimestamp?.call(event) ?? eventTimestamp(event),
        sourceOrder: sourceOrder++,
      ),
    );
  }
  for (final outbox in outboxItems) {
    items.add(
      ChatTimelineItem.outbox(
        outbox: outbox,
        timestamp: outboxTimestamp(outbox),
        sourceOrder: sourceOrder++,
      ),
    );
  }
  items.sort((a, b) {
    final timestampOrder = b.timestamp.compareTo(a.timestamp);
    if (timestampOrder != 0) return timestampOrder;
    return a._sourceOrder.compareTo(b._sourceOrder);
  });
  return items;
}

List<TOutbox> filterOutboxItemsShadowedByEvents<TEvent, TOutbox>({
  required List<TEvent> events,
  required List<TOutbox> outboxItems,
  required String? Function(TEvent event) eventSignature,
  required DateTime Function(TEvent event) eventTimestamp,
  required String? Function(TOutbox outbox) outboxSignature,
  required DateTime Function(TOutbox outbox) outboxTimestamp,
  Duration maxTimeDifference = const Duration(minutes: 5),
}) {
  final matches = matchOutboxItemsShadowedByEvents(
    events: events,
    outboxItems: outboxItems,
    eventSignature: eventSignature,
    eventTimestamp: eventTimestamp,
    outboxSignature: outboxSignature,
    outboxTimestamp: outboxTimestamp,
    maxTimeDifference: maxTimeDifference,
  );
  if (matches.isEmpty) return outboxItems;
  final shadowed = [for (final match in matches) match.outbox];
  final filtered = <TOutbox>[];
  for (final outbox in outboxItems) {
    final index = shadowed.indexWhere(
      (item) => identical(item, outbox) || item == outbox,
    );
    if (index == -1) {
      filtered.add(outbox);
    } else {
      shadowed.removeAt(index);
    }
  }
  return filtered;
}

class ChatOutboxEventMatch<TEvent, TOutbox> {
  const ChatOutboxEventMatch({
    required this.event,
    required this.outbox,
  });

  final TEvent event;
  final TOutbox outbox;
}

List<ChatOutboxEventMatch<TEvent, TOutbox>>
    matchOutboxItemsShadowedByEvents<TEvent, TOutbox>({
  required List<TEvent> events,
  required List<TOutbox> outboxItems,
  required String? Function(TEvent event) eventSignature,
  required DateTime Function(TEvent event) eventTimestamp,
  required String? Function(TOutbox outbox) outboxSignature,
  required DateTime Function(TOutbox outbox) outboxTimestamp,
  Duration maxTimeDifference = const Duration(minutes: 5),
}) {
  final eventBuckets = <String, List<_ChatEventMatchCandidate<TEvent>>>{};
  for (final event in events) {
    final signature = eventSignature(event);
    if (signature == null || signature.isEmpty) continue;
    eventBuckets.putIfAbsent(signature, () => []).add(
          _ChatEventMatchCandidate(
            event: event,
            timestamp: eventTimestamp(event),
          ),
        );
  }
  if (eventBuckets.isEmpty) return const [];

  for (final bucket in eventBuckets.values) {
    bucket.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  final matches = <ChatOutboxEventMatch<TEvent, TOutbox>>[];
  for (final outbox in outboxItems) {
    final signature = outboxSignature(outbox);
    if (signature == null || signature.isEmpty) {
      continue;
    }
    final bucket = eventBuckets[signature];
    if (bucket == null || bucket.isEmpty) {
      continue;
    }
    final outboxTime = outboxTimestamp(outbox);
    final matchIndex = bucket.indexWhere(
      (candidate) =>
          candidate.timestamp.difference(outboxTime).abs() <= maxTimeDifference,
    );
    if (matchIndex == -1) {
      continue;
    }
    final candidate = bucket.removeAt(matchIndex);
    matches.add(ChatOutboxEventMatch(event: candidate.event, outbox: outbox));
  }
  return matches;
}

class _ChatEventMatchCandidate<TEvent> {
  const _ChatEventMatchCandidate({
    required this.event,
    required this.timestamp,
  });

  final TEvent event;
  final DateTime timestamp;
}

List<TEvent> filterRecoveredUnreadEventsShadowedByTimeline<TEvent>({
  required Iterable<TEvent> timelineEvents,
  required Iterable<TEvent> recoveredEvents,
  required String? Function(TEvent event) eventId,
}) {
  final timelineEventIds = <String>{};
  for (final event in timelineEvents) {
    final id = eventId(event)?.trim() ?? '';
    if (id.isNotEmpty) timelineEventIds.add(id);
  }
  if (timelineEventIds.isEmpty) {
    return recoveredEvents.toList(growable: false);
  }
  final filtered = <TEvent>[];
  for (final event in recoveredEvents) {
    final id = eventId(event)?.trim() ?? '';
    if (id.isEmpty || !timelineEventIds.contains(id)) {
      filtered.add(event);
    }
  }
  return filtered;
}
