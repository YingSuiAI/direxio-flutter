// ignore_for_file: implementation_imports

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/models/timeline_chunk.dart';
import 'package:portal_app/presentation/chat/agent_message_content.dart';

void main() {
  test('agent matrix edit replaces the original message content', () {
    final projection = projectAgentMessageEvents<_FakeAgentEvent>(
      [
        const _FakeAgentEvent(
          id: r'$preview',
          content: {'msgtype': 'm.text', 'body': 'draft'},
        ),
        const _FakeAgentEvent(
          id: r'$edit',
          content: {
            'msgtype': 'm.text',
            'body': '* final',
            'm.new_content': {'msgtype': 'm.text', 'body': '**final**'},
            'm.relates_to': {'rel_type': 'm.replace', 'event_id': r'$preview'},
          },
        ),
      ],
      eventId: (event) => event.id,
      content: (event) => event.content,
      fallbackBody: (_) => '',
    );

    expect(projection.visibleEvents.map((event) => event.id), [r'$preview']);
    expect(
      projection.contentForEvent(projection.visibleEvents.single)!.markdown,
      '**final**',
    );
  });

  test('agent matrix aggregated edit uses the display event content', () {
    final client = Client('agent-message-content-test');
    final room = Room(id: '!agent:example.org', client: client);
    final original = Event(
      content: {'msgtype': 'm.text', 'body': 'draft'},
      type: EventTypes.Message,
      eventId: r'$preview',
      senderId: '@agent:example.org',
      originServerTs: DateTime.fromMillisecondsSinceEpoch(1),
      room: room,
    );
    final edit = Event(
      content: {
        'msgtype': 'm.text',
        'body': '* updated',
        'm.new_content': {'msgtype': 'm.text', 'body': 'updated'},
        'm.relates_to': {'rel_type': 'm.replace', 'event_id': r'$preview'},
      },
      type: EventTypes.Message,
      eventId: r'$edit',
      senderId: '@agent:example.org',
      originServerTs: DateTime.fromMillisecondsSinceEpoch(2),
      room: room,
    );
    final timeline = Timeline(
      room: room,
      chunk: TimelineChunk(events: [original, edit]),
    );
    addTearDown(timeline.cancelSubscriptions);

    final content = agentDisplayContentForEvent(original, timeline);

    expect(content['body'], 'updated');
    expect(content.containsKey('m.relates_to'), isFalse);
  });

  test('agent card content renders structured fields and text fallback', () {
    final content = agentMessageContentFromMatrixContent(const {
      'msgtype': 'm.text',
      'body': 'fallback text',
      'io.direxio.agent_card': {
        'header': {'title': 'Result'},
        'elements': [
          {'type': 'markdown', 'content': '**Done**'},
          {
            'type': 'actions',
            'buttons': [
              {'text': 'Open', 'value': 'cmd:/open'},
            ],
          },
        ],
      },
    }, fallbackBody: 'fallback text');

    expect(content.markdown, 'fallback text');
    expect(content.cards, hasLength(1));
    expect(content.cards.single.title, 'Result');
    expect(
      content.cards.single.blocks.map((block) => block.text),
      contains('**Done**'),
    );
    expect(content.cards.single.actions.single.label, 'Open');
  });
}

class _FakeAgentEvent {
  const _FakeAgentEvent({
    required this.id,
    required this.content,
  });

  final String id;
  final Map<String, Object?> content;
}
