import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/presentation/utils/chat_visibility_policy.dart';

class _Message {
  const _Message({
    required this.eventId,
    required this.originServerTs,
    this.redacted = false,
  });

  final String eventId;
  final int originServerTs;
  final bool redacted;
}

void main() {
  test('keeps only messages at or after the contact visibility boundary', () {
    const policy = ChatVisibilityPolicy(visibleAfterTs: 2000);

    final visible = policy.filter(
      const [
        _Message(eventId: r'$old', originServerTs: 1999),
        _Message(eventId: r'$first-visible', originServerTs: 2000),
        _Message(eventId: r'$new', originServerTs: 2001),
      ],
      eventId: (message) => message.eventId,
      originServerTs: (message) => message.originServerTs,
    );

    expect(visible.map((message) => message.eventId), [
      r'$first-visible',
      r'$new',
    ]);
  });

  test('uses one filter for cleared, deleted, and redacted messages', () {
    const policy = ChatVisibilityPolicy(
      clearedBeforeTs: 2000,
      deletedEventIds: {r'$deleted'},
    );

    final visible = policy.filter(
      const [
        _Message(eventId: r'$cleared', originServerTs: 1999),
        _Message(eventId: r'$deleted', originServerTs: 2001),
        _Message(eventId: r'$redacted', originServerTs: 2002, redacted: true),
        _Message(eventId: r'$kept', originServerTs: 2003),
      ],
      eventId: (message) => message.eventId,
      originServerTs: (message) => message.originServerTs,
      redacted: (message) => message.redacted,
    );

    expect(visible.map((message) => message.eventId), [r'$kept']);
  });
}
