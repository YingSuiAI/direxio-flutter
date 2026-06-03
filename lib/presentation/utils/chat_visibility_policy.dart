class ChatVisibilityPolicy {
  const ChatVisibilityPolicy({
    this.visibleAfterTs = 0,
    this.clearedBeforeTs = 0,
    this.deletedEventIds = const {},
  });

  final int visibleAfterTs;
  final int clearedBeforeTs;
  final Set<String> deletedEventIds;

  bool allows({
    required String eventId,
    required int originServerTs,
    bool redacted = false,
  }) {
    if (eventId.isNotEmpty && deletedEventIds.contains(eventId)) {
      return false;
    }
    if (redacted) return false;
    if (visibleAfterTs > 0 && originServerTs < visibleAfterTs) {
      return false;
    }
    if (clearedBeforeTs > 0 && originServerTs < clearedBeforeTs) {
      return false;
    }
    return true;
  }

  List<T> filter<T>(
    Iterable<T> messages, {
    required String Function(T message) eventId,
    required int Function(T message) originServerTs,
    bool Function(T message)? redacted,
  }) {
    return messages
        .where(
          (message) => allows(
            eventId: eventId(message),
            originServerTs: originServerTs(message),
            redacted: redacted?.call(message) ?? false,
          ),
        )
        .toList(growable: false);
  }
}
