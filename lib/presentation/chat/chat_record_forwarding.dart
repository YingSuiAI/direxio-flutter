import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';

const chatRecordMessageType = 'chat_record';
const chatRecordMatrixMarkerKey = 'p2p.message_type';
const chatRecordMatrixPayloadKey = 'p2p.chat_record';

class ChatRecordSourceMessage {
  const ChatRecordSourceMessage({
    required this.senderName,
    required this.body,
    required this.messageType,
    required this.originServerTs,
    this.senderId = '',
    this.isMe = false,
    this.content = const {},
  });

  final String senderId;
  final String senderName;
  final bool isMe;
  final String body;
  final String messageType;
  final int originServerTs;
  final Map<String, Object?> content;
}

class ChatRecordItem {
  const ChatRecordItem({
    required this.senderId,
    required this.senderName,
    required this.isMe,
    required this.body,
    required this.messageType,
    required this.originServerTs,
    required this.content,
  });

  final String senderId;
  final String senderName;
  final bool isMe;
  final String body;
  final String messageType;
  final int originServerTs;
  final Map<String, Object?> content;

  factory ChatRecordItem.fromMap(Map<String, Object?> map) {
    final content = _objectMap(map['content']);
    final msgType = _stringValue(map['message_type']).trim().isNotEmpty
        ? _stringValue(map['message_type']).trim()
        : _stringValue(content['msgtype']).trim();
    final body = _stringValue(map['body']).trim().isNotEmpty
        ? _stringValue(map['body']).trim()
        : _stringValue(content['body']).trim();
    return ChatRecordItem(
      senderId: _stringValue(map['sender_id']).trim(),
      senderName: _stringValue(map['sender_name']).trim(),
      isMe: map['is_me'] == true,
      body: body,
      messageType: msgType.isEmpty ? MessageTypes.Text : msgType,
      originServerTs: _intValue(map['origin_server_ts']),
      content: content.isEmpty
          ? <String, Object?>{
              'msgtype': msgType.isEmpty ? MessageTypes.Text : msgType,
              'body': body,
            }
          : content,
    );
  }

  String get filename {
    final value = _stringValue(content['filename']).trim();
    if (value.isNotEmpty) return value;
    return body;
  }

  String get mediaUrl => _stringValue(content['url']).trim();

  Map<String, Object?> get info => _objectMap(content['info']);

  String get mimeType => _stringValue(info['mimetype']).trim();

  int get size => _intValue(info['size']);

  String get thumbnailUrl {
    final value = _stringValue(info['thumbnail_url']).trim();
    if (value.isNotEmpty) return value;
    return mediaUrl;
  }

  int get width => _intValue(info['w']);

  int get height => _intValue(info['h']);

  int get durationMs => _intValue(info['duration']);
}

class ChatRecordPayload {
  const ChatRecordPayload({
    required this.sourceRoomId,
    required this.sourceRoomType,
    required this.title,
    required this.body,
    required this.itemCount,
    required this.items,
  });

  final String sourceRoomId;
  final String sourceRoomType;
  final String title;
  final String body;
  final int itemCount;
  final List<Map<String, Object?>> items;

  Map<String, dynamic> get matrixContent => {
        'msgtype': MessageTypes.Text,
        'body': body,
        chatRecordMatrixMarkerKey: chatRecordMessageType,
        chatRecordMatrixPayloadKey: {
          'title': title,
          'source_room_id': sourceRoomId,
          'source_room_type': sourceRoomType,
          'item_count': itemCount,
          'items': items,
        },
      };
}

ChatRecordPayload? chatRecordPayloadFromContent(
  Map<String, Object?> content,
) {
  if (content[chatRecordMatrixMarkerKey] != chatRecordMessageType) return null;
  final rawPayload = _objectMap(content[chatRecordMatrixPayloadKey]);
  final title = _stringValue(rawPayload['title']).trim();
  final sourceRoomId = _stringValue(rawPayload['source_room_id']).trim();
  final sourceRoomType = _stringValue(rawPayload['source_room_type']).trim();
  final rawItems = rawPayload['items'];
  final items = rawItems is List
      ? [
          for (final item in rawItems)
            if (item is Map)
              item.map(
                (key, value) => MapEntry(key.toString(), value as Object?),
              ),
        ]
      : <Map<String, Object?>>[];
  final itemCount = _intValue(rawPayload['item_count']);
  final body = _stringValue(content['body']).trim();
  return ChatRecordPayload(
    sourceRoomId: sourceRoomId,
    sourceRoomType: sourceRoomType.isEmpty ? 'direct' : sourceRoomType,
    title:
        title.isEmpty ? chatRecordTitleFromContent(content) ?? '聊天记录' : title,
    body: body.isEmpty
        ? '聊天记录\n${title.isEmpty ? '聊天记录' : title}\n共 ${itemCount == 0 ? items.length : itemCount} 条消息'
        : body,
    itemCount: itemCount == 0 ? items.length : itemCount,
    items: items,
  );
}

List<ChatRecordItem> chatRecordItems(ChatRecordPayload payload) {
  return [
    for (final item in payload.items) ChatRecordItem.fromMap(item),
  ];
}

class ChatRecordForwardTarget {
  const ChatRecordForwardTarget({
    required this.roomId,
    required this.name,
    required this.roomType,
    required this.sendViaAs,
  });

  final String roomId;
  final String name;
  final String roomType;
  final bool sendViaAs;
}

ChatRecordPayload buildChatRecordPayload({
  required String sourceRoomId,
  required String sourceRoomType,
  required String sourceName,
  required Iterable<ChatRecordSourceMessage> messages,
}) {
  final ordered = messages.toList(growable: false);
  if (ordered.length == 1) {
    final nested = chatRecordPayloadFromContent(ordered.single.content);
    if (nested != null) return nested;
  }
  final title = chatRecordTitle(
    sourceRoomType: sourceRoomType,
    sourceName: sourceName,
  );
  final items = <Map<String, Object?>>[];
  for (final message in ordered) {
    items.add(_chatRecordItemMapFromSource(message));
  }
  final itemCount = items.length;
  return ChatRecordPayload(
    sourceRoomId: sourceRoomId,
    sourceRoomType: sourceRoomType,
    title: title,
    body: '聊天记录\n$title\n共 $itemCount 条消息',
    itemCount: itemCount,
    items: items,
  );
}

Map<String, Object?> _chatRecordItemMapFromSource(
  ChatRecordSourceMessage message,
) {
  return {
    'sender_id': message.senderId.trim(),
    'sender_name': message.senderName.trim(),
    'is_me': message.isMe,
    'body': message.body.trim(),
    'message_type': message.messageType.trim(),
    'origin_server_ts': message.originServerTs,
    'content': message.content.isEmpty
        ? {
            'msgtype': message.messageType.trim().isEmpty
                ? MessageTypes.Text
                : message.messageType.trim(),
            'body': message.body.trim(),
          }
        : message.content,
  };
}

String chatRecordTitle({
  required String sourceRoomType,
  required String sourceName,
}) {
  final name = sourceName.trim();
  return switch (sourceRoomType) {
    'direct' => name.isEmpty ? '私聊聊天记录' : '与 $name 的聊天记录',
    'group' => name.isEmpty ? '群聊聊天记录' : '群聊「$name」的聊天记录',
    'channel' => name.isEmpty ? '频道聊天记录' : '频道「$name」的聊天记录',
    'agent' => '与 Agent 的聊天记录',
    _ => name.isEmpty ? '聊天记录' : '与 $name 的聊天记录',
  };
}

String? chatRecordTitleFromContent(Map<String, Object?> content) {
  if (content[chatRecordMatrixMarkerKey] != chatRecordMessageType) return null;
  final payload = content[chatRecordMatrixPayloadKey];
  if (payload is Map) {
    final title = payload['title'];
    if (title is String && title.trim().isNotEmpty) return title.trim();
  }
  final body = content['body'];
  if (body is! String) return '聊天记录';
  final lines = body
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  return lines.length >= 2 ? lines[1] : '聊天记录';
}

String _stringValue(Object? value) => value is String ? value : '';

int _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries) entry.key.toString(): entry.value,
  };
}

List<ChatRecordForwardTarget> chatRecordForwardTargets(
  AsSyncCacheState syncCache, {
  required String currentRoomId,
  required String currentRoomName,
  required String currentRoomType,
}) {
  final targets = <ChatRecordForwardTarget>[
    ChatRecordForwardTarget(
      roomId: currentRoomId,
      name: currentRoomName.trim().isEmpty ? '当前会话' : currentRoomName.trim(),
      roomType: currentRoomType,
      sendViaAs: currentRoomType == 'direct' || currentRoomType == 'group',
    ),
  ];
  final seen = <String>{currentRoomId};
  final bootstrap = syncCache.bootstrap;
  if (bootstrap == null) return targets;

  for (final contact in bootstrap.contacts) {
    if (contact.status != 'accepted' || contact.roomId.trim().isEmpty) {
      continue;
    }
    if (!seen.add(contact.roomId)) continue;
    targets.add(
      ChatRecordForwardTarget(
        roomId: contact.roomId,
        name: contact.displayName.trim().isEmpty
            ? contact.domain.trim()
            : contact.displayName.trim(),
        roomType: 'direct',
        sendViaAs: true,
      ),
    );
  }
  for (final group in bootstrap.groups) {
    if (group.roomId.trim().isEmpty || !seen.add(group.roomId)) continue;
    targets.add(
      ChatRecordForwardTarget(
        roomId: group.roomId,
        name: group.name.trim().isEmpty ? '未命名群聊' : group.name.trim(),
        roomType: 'group',
        sendViaAs: true,
      ),
    );
  }
  for (final channel in bootstrap.channels) {
    if (channel.roomId.trim().isEmpty || !seen.add(channel.roomId)) continue;
    targets.add(
      ChatRecordForwardTarget(
        roomId: channel.roomId,
        name: channel.name.trim().isEmpty ? '未命名频道' : channel.name.trim(),
        roomType: 'channel',
        sendViaAs: false,
      ),
    );
  }
  return targets;
}

Future<bool> showAndForwardChatRecord(
  BuildContext context,
  WidgetRef ref, {
  required ChatRecordPayload payload,
  required String currentRoomId,
  required String currentRoomName,
  required String currentRoomType,
}) async {
  final targets = chatRecordForwardTargets(
    ref.read(asSyncCacheProvider),
    currentRoomId: currentRoomId,
    currentRoomName: currentRoomName,
    currentRoomType: currentRoomType,
  );
  final target = await showModalBottomSheet<ChatRecordForwardTarget>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => _ForwardTargetSheet(targets: targets),
  );
  if (target == null) return false;
  await sendChatRecordToTarget(ref, target: target, payload: payload);
  return true;
}

Future<void> sendChatRecordToTarget(
  WidgetRef ref, {
  required ChatRecordForwardTarget target,
  required ChatRecordPayload payload,
}) async {
  if (target.sendViaAs) {
    await ref.read(asClientProvider).sendChatRecordMessage(
          roomId: target.roomId,
          body: payload.body,
          title: payload.title,
          sourceRoomId: payload.sourceRoomId,
          sourceRoomType: payload.sourceRoomType,
          itemCount: payload.itemCount,
          items: payload.items,
        );
    await ref.read(matrixClientProvider).oneShotSync();
    return;
  }

  final room = ref.read(matrixClientProvider).getRoomById(target.roomId);
  if (room == null) {
    throw StateError('目标会话未同步到本地');
  }
  await room.sendEvent(payload.matrixContent);
}

class ChatRecordSelectionBar extends StatelessWidget {
  const ChatRecordSelectionBar({
    super.key,
    required this.count,
    required this.onExit,
    required this.onForward,
    this.onDelete,
    this.onFavorite,
    this.compact = false,
  });

  final int count;
  final VoidCallback onExit;
  final VoidCallback onForward;
  final VoidCallback? onDelete;
  final VoidCallback? onFavorite;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    if (compact) {
      final actions = <Widget>[
        if (onDelete != null)
          _CompactSelectionAction(
            tooltip: '删除',
            icon: Symbols.delete,
            onTap: count > 0 ? onDelete : null,
          ),
        if (onFavorite != null)
          _CompactSelectionAction(
            tooltip: '收藏',
            icon: Symbols.bookmark,
            onTap: count > 0 ? onFavorite : null,
          ),
        _CompactSelectionAction(
          tooltip: '转发',
          icon: Symbols.ios_share,
          onTap: count > 0 ? onForward : null,
        ),
      ];
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Row(
            children: [
              for (final action in actions) Expanded(child: action),
            ],
          ),
        ),
      );
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: t.bg.withValues(alpha: 0.92),
            border: Border(
              top: BorderSide(color: t.border.withValues(alpha: 0.5)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: onExit,
                    icon: Icon(Symbols.close, size: 18, color: t.text),
                    label: Text(
                      '取消',
                      style: AppTheme.sans(size: 13, color: t.text),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '已选 $count 条',
                        style: AppTheme.sans(
                          size: 13,
                          color: t.textMute,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '转发',
                    icon: Icon(Symbols.forward, color: t.accent, size: 22),
                    onPressed: count > 0 ? onForward : null,
                  ),
                  if (onFavorite != null)
                    IconButton(
                      tooltip: '收藏',
                      icon: Icon(Symbols.bookmark, color: t.accent, size: 22),
                      onPressed: count > 0 ? onFavorite : null,
                    ),
                  if (onDelete != null)
                    IconButton(
                      tooltip: '删除',
                      icon: Icon(Symbols.delete, color: t.danger, size: 22),
                      onPressed: count > 0 ? onDelete : null,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactSelectionAction extends StatelessWidget {
  const _CompactSelectionAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Tooltip(
      message: tooltip,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 9.6, sigmaY: 9.6),
          child: Material(
            color: t.surfaceHigh.withValues(alpha: 0.8),
            shape: CircleBorder(
              side: BorderSide(
                color: t.surface.withValues(alpha: 0.9),
                width: 1.2,
              ),
            ),
            shadowColor: t.text.withValues(alpha: 0.12),
            elevation: 8,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Opacity(
                opacity: onTap == null ? 0.38 : 1,
                child: SizedBox.square(
                  dimension: 48,
                  child: Icon(icon, size: 28, color: t.text),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ForwardTargetSheet extends StatelessWidget {
  const _ForwardTargetSheet({required this.targets});

  final List<ChatRecordForwardTarget> targets;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '转发聊天记录',
              style: AppTheme.sans(
                size: 20,
                weight: FontWeight.w600,
                color: t.text,
              ),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: targets.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: t.border),
                itemBuilder: (context, index) {
                  final target = targets[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      switch (target.roomType) {
                        'direct' => Symbols.person,
                        'channel' => Symbols.campaign,
                        _ => Symbols.groups,
                      },
                      color: t.textMute,
                    ),
                    title: Text(
                      target.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(_targetTypeLabel(target.roomType)),
                    onTap: () => Navigator.of(context).pop(target),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _targetTypeLabel(String roomType) {
  return switch (roomType) {
    'direct' => '私聊',
    'channel' => '频道',
    'agent' => 'Agent',
    _ => '群聊',
  };
}
