import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/presentation/chat/chat_timeline_items.dart';

void main() {
  test('merges local outbox items into Matrix events by timestamp', () {
    final items = mergeChatTimelineItems<String, String>(
      events: const ['sent-22:29', 'sent-22:10'],
      eventTimestamp: (event) => switch (event) {
        'sent-22:29' => DateTime.parse('2026-05-28T14:29:00Z'),
        'sent-22:10' => DateTime.parse('2026-05-28T14:10:00Z'),
        _ => DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      },
      outboxItems: const ['failed-22:17'],
      outboxTimestamp: (_) => DateTime.parse('2026-05-28T14:17:00Z'),
    );

    expect(
      items.map(
        (item) => item.when(
          event: (event) => event,
          outbox: (outbox) => outbox,
        ),
      ),
      const ['sent-22:29', 'failed-22:17', 'sent-22:10'],
    );
  });

  test('keeps picker order for outbox images created in the same batch', () {
    final items = mergeChatTimelineItems<String, _OutboxItem>(
      events: const [],
      eventTimestamp: (_) =>
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      outboxItems: [
        _OutboxItem('image-1', DateTime.parse('2026-05-28T14:17:00.000000Z')),
        _OutboxItem('image-2', DateTime.parse('2026-05-28T14:17:00.000001Z')),
        _OutboxItem('image-3', DateTime.parse('2026-05-28T14:17:00.000002Z')),
      ],
      outboxTimestamp: (item) => item.createdAt,
    );

    expect(
      items.map((item) => item.outboxOrNull?.id),
      const ['image-3', 'image-2', 'image-1'],
    );
  });

  test(
      'uses local outbox order for delivered Matrix events from the same batch',
      () {
    final items = mergeChatTimelineItems<String, Never>(
      events: const ['sent-1', 'sent-2', 'sent-3'],
      eventTimestamp: (event) => switch (event) {
        'sent-1' => DateTime.parse('2026-05-28T14:29:30Z'),
        'sent-2' => DateTime.parse('2026-05-28T14:29:10Z'),
        'sent-3' => DateTime.parse('2026-05-28T14:29:20Z'),
        _ => DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      },
      eventSortTimestamp: (event) => switch (event) {
        'sent-1' => DateTime.parse('2026-05-28T14:17:00.000000Z'),
        'sent-2' => DateTime.parse('2026-05-28T14:17:00.000001Z'),
        'sent-3' => DateTime.parse('2026-05-28T14:17:00.000002Z'),
        _ => null,
      },
      outboxItems: const [],
      outboxTimestamp: (_) => DateTime.fromMillisecondsSinceEpoch(0),
    );

    expect(
      items
          .map((item) => item.when(event: (event) => event, outbox: (_) => '')),
      const ['sent-3', 'sent-2', 'sent-1'],
    );
  });

  test('filters local outbox text shadowed by a nearby event echo', () {
    final outboxTime = DateTime.parse('2026-05-28T14:17:00Z');
    final items = filterOutboxItemsShadowedByEvents<_EchoEvent, _OutboxItem>(
      events: [
        _EchoEvent('text:hello', outboxTime.add(const Duration(seconds: 8))),
      ],
      outboxItems: [
        _OutboxItem('failed-text', outboxTime, signature: 'text:hello'),
        _OutboxItem('real-failed', outboxTime, signature: 'text:still-failed'),
      ],
      eventSignature: (event) => event.signature,
      eventTimestamp: (event) => event.createdAt,
      outboxSignature: (item) => item.signature,
      outboxTimestamp: (item) => item.createdAt,
    );

    expect(items.map((item) => item.id), const ['real-failed']);
  });

  test('filters shadowed outbox text by matching event count only', () {
    final outboxTime = DateTime.parse('2026-05-28T14:17:00Z');
    final items = filterOutboxItemsShadowedByEvents<_EchoEvent, _OutboxItem>(
      events: [
        _EchoEvent('text:hello', outboxTime.add(const Duration(seconds: 8))),
      ],
      outboxItems: [
        _OutboxItem('first', outboxTime, signature: 'text:hello'),
        _OutboxItem(
          'second',
          outboxTime.add(const Duration(seconds: 1)),
          signature: 'text:hello',
        ),
      ],
      eventSignature: (event) => event.signature,
      eventTimestamp: (event) => event.createdAt,
      outboxSignature: (item) => item.signature,
      outboxTimestamp: (item) => item.createdAt,
    );

    expect(items.map((item) => item.id), const ['second']);
  });

  test('returns event to outbox matches for delivered media echoes', () {
    final outboxTime = DateTime.parse('2026-05-28T14:17:00Z');
    final matches = matchOutboxItemsShadowedByEvents<_EchoEvent, _OutboxItem>(
      events: [
        _EchoEvent(
          'image:photo.jpg:120',
          outboxTime.add(const Duration(seconds: 5)),
          eventId: r'$photo',
        ),
        _EchoEvent(
          'video:clip.mp4:320',
          outboxTime.add(const Duration(seconds: 6)),
          eventId: r'$clip',
        ),
      ],
      outboxItems: [
        _OutboxItem(
          'pending-photo',
          outboxTime,
          signature: 'image:photo.jpg:120',
        ),
        _OutboxItem(
          'pending-other',
          outboxTime,
          signature: 'image:other.jpg:120',
        ),
        _OutboxItem(
          'pending-clip',
          outboxTime,
          signature: 'video:clip.mp4:320',
        ),
      ],
      eventSignature: (event) => event.signature,
      eventTimestamp: (event) => event.createdAt,
      outboxSignature: (item) => item.signature,
      outboxTimestamp: (item) => item.createdAt,
    );

    expect(matches.map((match) => match.event.eventId), const [
      r'$photo',
      r'$clip',
    ]);
    expect(matches.map((match) => match.outbox.id), const [
      'pending-photo',
      'pending-clip',
    ]);
  });

  test('filters recovered unread events already present in Matrix timeline',
      () {
    final recovered = filterRecoveredUnreadEventsShadowedByTimeline<String>(
      timelineEvents: const ['\$timeline-old', '\$timeline-new'],
      recoveredEvents: const [
        '\$timeline-old',
        '\$recovered-only',
        '   ',
      ],
      eventId: (event) => event,
    );

    expect(recovered, const ['\$recovered-only', '   ']);
  });

  test('filters recovered unread events by stable event id only', () {
    final recovered = filterRecoveredUnreadEventsShadowedByTimeline<_EchoEvent>(
      timelineEvents: [
        _EchoEvent('same body', DateTime.utc(2026, 6, 22, 10),
            eventId: '\$matrix'),
      ],
      recoveredEvents: [
        _EchoEvent('same body', DateTime.utc(2026, 6, 22, 10),
            eventId: '\$recovered'),
      ],
      eventId: (event) => event.eventId,
    );

    expect(recovered.map((event) => event.eventId), const ['\$recovered']);
  });
}

class _OutboxItem {
  const _OutboxItem(this.id, this.createdAt, {this.signature});

  final String id;
  final DateTime createdAt;
  final String? signature;
}

class _EchoEvent {
  const _EchoEvent(this.signature, this.createdAt, {this.eventId = ''});

  final String signature;
  final DateTime createdAt;
  final String eventId;
}
