import 'package:matrix/matrix.dart';

class AgentMessageContent {
  const AgentMessageContent({
    required this.markdown,
    this.cards = const [],
    this.isGenerating = false,
  });

  final String markdown;
  final List<AgentMessageCard> cards;
  final bool isGenerating;
}

Map<String, Object?> agentDisplayContentForEvent(
    Event event, Timeline? timeline) {
  final displayEvent =
      timeline == null ? event : event.getDisplayEvent(timeline);
  return Map<String, Object?>.from(displayEvent.content);
}

String agentDisplayFallbackBodyForEvent(Event event, Timeline? timeline) {
  final displayEvent =
      timeline == null ? event : event.getDisplayEvent(timeline);
  return displayEvent.calcUnlocalizedBody(hideEdit: true).trim();
}

class AgentMessageCard {
  const AgentMessageCard({
    this.title = '',
    this.color = '',
    this.blocks = const [],
    this.actions = const [],
  });

  final String title;
  final String color;
  final List<AgentMessageCardBlock> blocks;
  final List<AgentMessageCardAction> actions;

  bool get isEmpty => title.trim().isEmpty && blocks.isEmpty && actions.isEmpty;
}

class AgentMessageCardBlock {
  const AgentMessageCardBlock({required this.kind, required this.text});

  final String kind;
  final String text;
}

class AgentMessageCardAction {
  const AgentMessageCardAction({
    required this.label,
    this.value = '',
    this.kind = '',
  });

  final String label;
  final String value;
  final String kind;
}

class AgentMessageTimelineProjection<T extends Object> {
  const AgentMessageTimelineProjection({
    required this.visibleEvents,
    required Map<String, AgentMessageContent> contentByKey,
  }) : _contentByKey = contentByKey;

  final List<T> visibleEvents;
  final Map<String, AgentMessageContent> _contentByKey;

  AgentMessageContent? contentForEvent(T event) {
    return _contentByKey[_eventObjectKey(event)];
  }
}

class _StreamFragment<T extends Object> {
  const _StreamFragment({
    required this.content,
    required this.timestampMs,
    required this.sequence,
  });

  final Map<String, Object?> content;
  final int timestampMs;
  final int sequence;
}

AgentMessageTimelineProjection<T> projectAgentMessageEvents<T extends Object>(
  List<T> events, {
  required String Function(T event) eventId,
  required Map<String, Object?> Function(T event) content,
  required String Function(T event) fallbackBody,
  required int Function(T event) timestampMs,
}) {
  final visible = <T>[];
  final hiddenKeys = <String>{};
  final replacementByTargetId = <String, Map<String, Object?>>{};
  final streamGroups = <String, List<_StreamFragment<T>>>{};
  final streamRootKey = <String, String>{};
  final contentByKey = <String, AgentMessageContent>{};

  for (final event in events) {
    final currentContent = content(event);
    final targetId = matrixReplacementTargetEventId(currentContent);
    if (targetId.isNotEmpty) {
      replacementByTargetId[targetId] = currentContent;
      hiddenKeys.add(_eventObjectKey(event));
      continue;
    }

    final streamId = agentStreamIdFromContent(currentContent);
    if (streamId.isNotEmpty) {
      final key = _eventObjectKey(event);
      streamRootKey.putIfAbsent(streamId, () => key);
      if (streamRootKey[streamId] != key) hiddenKeys.add(key);
      streamGroups.putIfAbsent(streamId, () => []).add(
            _StreamFragment(
              content: currentContent,
              timestampMs: timestampMs(event),
              sequence: agentStreamSequenceFromContent(currentContent),
            ),
          );
    }
  }

  for (final event in events) {
    if (!hiddenKeys.contains(_eventObjectKey(event))) visible.add(event);
  }

  for (final event in visible) {
    final key = _eventObjectKey(event);
    final id = eventId(event).trim();
    final replacement = id.isEmpty ? null : replacementByTargetId[id];
    if (replacement != null) {
      contentByKey[key] = agentMessageContentFromMatrixContent(
        replacement,
        fallbackBody: fallbackBody(event),
      );
      continue;
    }

    final currentContent = content(event);
    final streamId = agentStreamIdFromContent(currentContent);
    final fragments = streamId.isEmpty ? null : streamGroups[streamId];
    if (fragments != null && fragments.isNotEmpty) {
      contentByKey[key] = _contentFromStreamFragments(
        fragments,
        fallbackBody: fallbackBody(event),
      );
      continue;
    }

    contentByKey[key] = agentMessageContentFromMatrixContent(
      currentContent,
      fallbackBody: fallbackBody(event),
    );
  }

  return AgentMessageTimelineProjection<T>(
    visibleEvents: visible,
    contentByKey: contentByKey,
  );
}

AgentMessageContent agentMessageContentFromMatrixContent(
  Map<String, Object?> content, {
  required String fallbackBody,
}) {
  final effective = _effectiveMessageContent(content);
  final markdown = _firstString([
    effective['body'],
    effective['formatted_body'],
    content['body'],
    fallbackBody,
  ]).trim();
  return AgentMessageContent(
    markdown: _stripMatrixEditFallback(markdown),
    cards: agentMessageCardsFromContent(effective),
    isGenerating: _boolFromAny(effective['is_generating']) ||
        _boolFromAny(effective['generating']),
  );
}

List<AgentMessageCard> agentMessageCardsFromContent(
  Map<String, Object?> content,
) {
  final rawCards = <Object?>[
    content['io.direxio.agent_cards'],
    content['io.direxio.cards'],
    content['agent_cards'],
    content['cards'],
  ];
  final rawSingleCards = <Object?>[
    content['io.direxio.agent_card'],
    content['io.direxio.card'],
    content['agent_card'],
    content['card'],
  ];

  final cards = <AgentMessageCard>[];
  for (final raw in rawCards) {
    if (raw is Iterable) {
      for (final item in raw) {
        final card = _cardFromAny(item);
        if (card != null && !card.isEmpty) cards.add(card);
      }
    }
  }
  for (final raw in rawSingleCards) {
    final card = _cardFromAny(raw);
    if (card != null && !card.isEmpty) cards.add(card);
  }
  return cards;
}

String matrixReplacementTargetEventId(Map<String, Object?> content) {
  final relates = content['m.relates_to'];
  if (relates is! Map) return '';
  final relType = _stringFromAny(relates['rel_type']).trim();
  if (relType != 'm.replace') return '';
  return _stringFromAny(relates['event_id']).trim();
}

String agentStreamIdFromContent(Map<String, Object?> content) {
  final stream = _streamMap(content);
  return _firstString([
    stream?['stream_id'],
    stream?['reply_id'],
    stream?['turn_id'],
    content['stream_id'],
    content['reply_id'],
    content['turn_id'],
    content['io.direxio.agent_stream_id'],
  ]).trim();
}

int agentStreamSequenceFromContent(Map<String, Object?> content) {
  final stream = _streamMap(content);
  return _intFromAny(
    stream?['seq'] ??
        stream?['sequence'] ??
        content['seq'] ??
        content['sequence'],
  );
}

AgentMessageContent _contentFromStreamFragments<T extends Object>(
  List<_StreamFragment<T>> fragments, {
  required String fallbackBody,
}) {
  final ordered = [...fragments]..sort((a, b) {
      final bySeq = a.sequence.compareTo(b.sequence);
      if (bySeq != 0) return bySeq;
      return a.timestampMs.compareTo(b.timestampMs);
    });

  final buffer = StringBuffer();
  var generating = true;
  var cards = const <AgentMessageCard>[];
  for (final fragment in ordered) {
    final content = fragment.content;
    final stream = _streamMap(content);
    final done = _boolFromAny(stream?['done']) ||
        _boolFromAny(stream?['complete']) ||
        _boolFromAny(content['done']) ||
        _boolFromAny(content['complete']);
    final mode = _firstString([
      stream?['body_mode'],
      stream?['mode'],
      content['body_mode'],
      content['mode'],
    ]).trim();
    final finalText = _firstString([
      stream?['final_body'],
      content['final_body'],
      if (done) stream?['body'],
      if (done) content['body'],
    ]);
    final text = _firstString([
      stream?['delta'],
      stream?['text_delta'],
      content['delta'],
      content['text_delta'],
      if (mode == 'replace') stream?['body'],
      if (mode == 'replace') content['body'],
    ]);
    if (done && finalText.trim().isNotEmpty) {
      buffer
        ..clear()
        ..write(finalText);
    } else if (mode == 'replace' || _boolFromAny(stream?['replace'])) {
      buffer
        ..clear()
        ..write(text);
    } else {
      buffer.write(text);
    }
    if (done) {
      generating = false;
    }
    final parsed = agentMessageContentFromMatrixContent(
      content,
      fallbackBody: fallbackBody,
    );
    if (done) {
      cards = parsed.cards;
    } else if (parsed.cards.isNotEmpty) {
      cards = parsed.cards;
    }
  }

  final markdown = buffer.toString().trim().isNotEmpty
      ? buffer.toString().trim()
      : fallbackBody.trim();
  return AgentMessageContent(
    markdown: markdown,
    cards: cards,
    isGenerating: generating,
  );
}

Map<String, Object?> _effectiveMessageContent(Map<String, Object?> content) {
  final replacement = content['m.new_content'];
  if (replacement is Map) {
    return replacement.cast<String, Object?>();
  }
  return content;
}

Map<String, Object?>? _streamMap(Map<String, Object?> content) {
  for (final key in const [
    'io.direxio.agent_stream',
    'agent_stream',
    'stream',
  ]) {
    final value = content[key];
    if (value is Map) return value.cast<String, Object?>();
  }
  return null;
}

AgentMessageCard? _cardFromAny(Object? raw) {
  if (raw is! Map) return null;
  final map = raw.cast<String, Object?>();
  final header = map['header'];
  final headerMap = header is Map ? header.cast<String, Object?>() : null;
  final title = _firstString([
    headerMap?['title'],
    map['title'],
    map['name'],
  ]).trim();
  final color = _firstString([headerMap?['color'], map['color']]).trim();
  final blocks = <AgentMessageCardBlock>[];
  final actions = <AgentMessageCardAction>[];

  final elements = map['elements'];
  if (elements is Iterable) {
    for (final rawElement in elements) {
      if (rawElement is! Map) continue;
      final element = rawElement.cast<String, Object?>();
      final type = _firstString([
        element['type'],
        element['tag'],
        element['kind'],
      ]).trim();
      switch (type) {
        case 'divider':
        case 'hr':
          blocks.add(const AgentMessageCardBlock(kind: 'divider', text: ''));
          break;
        case 'actions':
        case 'action':
          actions.addAll(_actionsFromAny(element['buttons']));
          break;
        case 'list_item':
        case 'listItem':
          final text = _firstString([element['text'], element['description']]);
          if (text.trim().isNotEmpty) {
            blocks.add(AgentMessageCardBlock(kind: 'text', text: text.trim()));
          }
          final label = _firstString([element['btn_text'], element['btnText']]);
          if (label.trim().isNotEmpty) {
            actions.add(
              AgentMessageCardAction(
                label: label.trim(),
                value: _firstString([
                  element['btn_value'],
                  element['btnValue'],
                ]),
                kind: _firstString([element['btn_type'], element['btnType']]),
              ),
            );
          }
          break;
        default:
          final text = _firstString([
            element['content'],
            element['text'],
            element['markdown'],
            element['body'],
          ]).trim();
          if (text.isNotEmpty) {
            blocks.add(
              AgentMessageCardBlock(
                kind: type.isEmpty ? 'markdown' : type,
                text: text,
              ),
            );
          }
      }
    }
  }

  actions.addAll(_actionsFromAny(map['actions']));
  actions.addAll(_actionsFromAny(map['buttons']));

  return AgentMessageCard(
    title: title,
    color: color,
    blocks: blocks,
    actions: actions,
  );
}

List<AgentMessageCardAction> _actionsFromAny(Object? raw) {
  if (raw is! Iterable) return const [];
  final actions = <AgentMessageCardAction>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final map = item.cast<String, Object?>();
    final label = _firstString([
      map['text'],
      map['label'],
      map['title'],
    ]).trim();
    if (label.isEmpty) continue;
    actions.add(
      AgentMessageCardAction(
        label: label,
        value: _firstString([map['value'], map['action'], map['command']]),
        kind: _firstString([map['type'], map['style'], map['kind']]),
      ),
    );
  }
  return actions;
}

String _stripMatrixEditFallback(String text) {
  final trimmed = text.trim();
  if (!trimmed.startsWith('* ')) return trimmed;
  return trimmed.substring(2).trim();
}

String _eventObjectKey(Object event) => identityHashCode(event).toString();

String _firstString(Iterable<Object?> values) {
  for (final value in values) {
    final string = _stringFromAny(value);
    if (string.trim().isNotEmpty) return string;
  }
  return '';
}

String _stringFromAny(Object? value) {
  if (value == null) return '';
  if (value is String) return value;
  return value.toString();
}

int _intFromAny(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _boolFromAny(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}
