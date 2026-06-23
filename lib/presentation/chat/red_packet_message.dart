import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import 'chat_message_cards.dart';

const redPacketCustomType = 923;
const mineRedPacketCustomType = 932;

class RedPacketPayload {
  const RedPacketPayload({
    required this.packetNo,
    required this.isMine,
    required this.isGroup,
    required this.title,
    required this.blessing,
    required this.amount,
    required this.currency,
    required this.raw,
  });

  final String packetNo;
  final bool isMine;
  final bool isGroup;
  final String title;
  final String blessing;
  final String amount;
  final String currency;
  final Map<String, Object?> raw;
}

RedPacketPayload? redPacketPayloadFromContent(
  Map<String, Object?> content, {
  String body = '',
}) {
  final candidates = <Map<String, Object?>>[
    content,
    for (final key in const [
      'data',
      'payload',
      'custom',
      'custom_data',
      'customData',
      'p2p.custom',
      'p2p.red_packet',
    ])
      ..._objectCandidates(content[key]),
    ..._objectCandidates(content['body']),
    ..._objectCandidates(body),
  ];

  for (final candidate in candidates) {
    final payload = _payloadObject(candidate);
    final customType = _intValue(
      candidate['customType'] ??
          candidate['custom_type'] ??
          candidate['businessType'] ??
          candidate['type'] ??
          payload['customType'] ??
          payload['custom_type'] ??
          payload['businessType'] ??
          payload['type'],
    );
    final packetNo = _redPacketNo(payload) ?? _redPacketNo(candidate);
    final isKnownType = customType == redPacketCustomType ||
        customType == mineRedPacketCustomType;
    if (!isKnownType && packetNo == null) continue;
    if (!isKnownType && !_looksLikeRedPacket(payload, candidate)) continue;
    final isMine = customType == mineRedPacketCustomType ||
        _boolValue(payload['isMineRedPacket']) ||
        _boolValue(payload['mineRedPacket']) ||
        _stringValue(payload['gameplayType']).toLowerCase().contains('mine');
    final title = _firstText([
      payload['title'],
      payload['name'],
      payload['packetName'],
      payload['redPacketName'],
      candidate['description'],
    ]);
    final blessing = _firstText([
      payload['blessing'],
      payload['greeting'],
      payload['remark'],
      payload['desc'],
      payload['description'],
      candidate['description'],
      body,
    ]);
    final amount = _firstText([
      payload['amount'],
      payload['totalAmount'],
      payload['total_amount'],
      payload['money'],
    ]);
    final currency = _firstText([
      payload['currencyName'],
      payload['currency'],
      payload['coinName'],
    ]);
    return RedPacketPayload(
      packetNo: packetNo ?? '',
      isMine: isMine,
      isGroup: (_intValue(payload['packetType']) ?? 0) > 0 ||
          _boolValue(payload['isGroup']) ||
          _boolValue(payload['is_group']),
      title: title.isEmpty ? (isMine ? '扫雷红包' : '红包') : title,
      blessing: blessing,
      amount: amount,
      currency: currency.isEmpty ? 'USDT' : currency,
      raw: payload,
    );
  }
  return null;
}

class RedPacketMessageCard extends StatelessWidget {
  const RedPacketMessageCard({
    super.key,
    required this.payload,
    required this.isMe,
    this.selected = false,
    this.onTap,
    this.onLongPressAt,
  });

  final RedPacketPayload payload;
  final bool isMe;
  final bool selected;
  final VoidCallback? onTap;
  final ValueChanged<Offset>? onLongPressAt;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final title = payload.isMine ? '扫雷红包' : '红包';
    final subtitle = payload.blessing.isEmpty ? '恭喜发财，大吉大利' : payload.blessing;
    final background =
        selected ? t.accent.withValues(alpha: 0.18) : const Color(0xFFE95445);
    var pressPosition = Offset.zero;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        debugPrint('[chat gesture] redPacket tap fire hasTap=${onTap != null}');
        onTap?.call();
      },
      onTapDown: (details) {
        pressPosition = details.globalPosition;
        debugPrint(
          '[chat gesture] redPacket tapDown pos=$pressPosition hasTap=${onTap != null} hasLong=${onLongPressAt != null}',
        );
      },
      onLongPress: () {
        debugPrint(
          '[chat gesture] redPacket longPress fire pos=$pressPosition hasLong=${onLongPressAt != null}',
        );
        onLongPressAt?.call(pressPosition);
      },
      onSecondaryTapDown: (details) {
        pressPosition = details.globalPosition;
        debugPrint(
          '[chat gesture] redPacket secondaryTapDown pos=$pressPosition hasLong=${onLongPressAt != null}',
        );
      },
      onSecondaryTap: () {
        debugPrint(
          '[chat gesture] redPacket secondaryTap fire pos=$pressPosition hasLong=${onLongPressAt != null}',
        );
        onLongPressAt?.call(pressPosition);
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 236),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: chatMessageBubbleRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD982),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Symbols.featured_seasonal_and_gifts,
                        color: Color(0xFFC23A2D),
                        size: 25,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.sans(
                              size: 16,
                              weight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.sans(
                              size: 13,
                              color: Colors.white.withValues(alpha: 0.86),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.vertical(
                    bottom: chatMessageBubbleRadius.bottomLeft,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 7, 12, 8),
                  child: Text(
                    payload.isMine ? '查看扫雷红包详情' : '查看红包详情',
                    style: AppTheme.sans(
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RedPacketDetailPage extends StatelessWidget {
  const RedPacketDetailPage({super.key, required this.payload});

  final RedPacketPayload payload;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Text(payload.isMine ? '扫雷红包详情' : '红包详情'),
        backgroundColor: t.bg,
        foregroundColor: t.text,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFE95445),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Symbols.featured_seasonal_and_gifts,
                color: Color(0xFFFFD982),
                size: 42,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            payload.title,
            textAlign: TextAlign.center,
            style:
                AppTheme.sans(size: 22, weight: FontWeight.w700, color: t.text),
          ),
          if (payload.blessing.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              payload.blessing,
              textAlign: TextAlign.center,
              style: AppTheme.sans(size: 14, color: t.textMute),
            ),
          ],
          const SizedBox(height: 24),
          _RedPacketDetailRow(label: '红包编号', value: payload.packetNo),
          _RedPacketDetailRow(
              label: '类型', value: payload.isMine ? '扫雷红包' : '普通红包'),
          _RedPacketDetailRow(
              label: '会话', value: payload.isGroup ? '群聊' : '单聊'),
          if (payload.amount.isNotEmpty)
            _RedPacketDetailRow(
              label: '金额',
              value: '${payload.amount} ${payload.currency}',
            ),
        ],
      ),
    );
  }
}

class _RedPacketDetailRow extends StatelessWidget {
  const _RedPacketDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child:
                Text(label, style: AppTheme.sans(size: 14, color: t.textMute)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              style: AppTheme.sans(size: 15, color: t.text),
            ),
          ),
        ],
      ),
    );
  }
}

List<Map<String, Object?>> _objectCandidates(Object? value) {
  if (value is Map) return [_stringKeyMap(value)];
  final text = _stringValue(value);
  if (text.isEmpty) return const [];
  final decoded = _decodeObject(text);
  return decoded == null ? const [] : [decoded];
}

Map<String, Object?> _payloadObject(Map<String, Object?> object) {
  final data = object['data'];
  if (data is Map) return _stringKeyMap(data);
  final decodedData = _objectCandidates(data);
  if (decodedData.isNotEmpty) return _payloadObject(decodedData.first);
  final payload = object['payload'];
  if (payload is Map) return _stringKeyMap(payload);
  final decodedPayload = _objectCandidates(payload);
  if (decodedPayload.isNotEmpty) return _payloadObject(decodedPayload.first);
  return object;
}

Map<String, Object?>? _decodeObject(String text) {
  final trimmed = text.trim();
  if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) return null;
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map) return _stringKeyMap(decoded);
  } on Object {
    return null;
  }
  return null;
}

Map<String, Object?> _stringKeyMap(Map<dynamic, dynamic> map) {
  return {
    for (final entry in map.entries) entry.key.toString(): entry.value,
  };
}

String? _redPacketNo(Map<String, Object?> payload) {
  for (final key in const [
    'packetNo',
    'redPacketNo',
    'redPacketId',
    'packetId',
    'id',
  ]) {
    final value = _stringValue(payload[key]);
    if (value.isNotEmpty) return value;
  }
  return null;
}

bool _looksLikeRedPacket(
  Map<String, Object?> payload,
  Map<String, Object?> envelope,
) {
  final joined = [
    _stringValue(payload['title']),
    _stringValue(payload['name']),
    _stringValue(payload['packetName']),
    _stringValue(payload['redPacketName']),
    _stringValue(payload['remark']),
    _stringValue(envelope['description']),
  ].join(' ');
  return joined.contains('红包') || joined.toLowerCase().contains('red packet');
}

String _firstText(List<Object?> values) {
  for (final value in values) {
    final text = _stringValue(value);
    if (text.isNotEmpty && !text.startsWith('{')) return text;
  }
  return '';
}

String _stringValue(Object? value) {
  if (value == null) return '';
  final text = value.toString().trim();
  if (text == 'null') return '';
  return text;
}

int? _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(_stringValue(value));
}

bool _boolValue(Object? value) {
  if (value is bool) return value;
  final text = _stringValue(value).toLowerCase();
  return text == 'true' || text == '1' || text == 'yes';
}
