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
