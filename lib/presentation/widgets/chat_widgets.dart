import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:intl/intl.dart';
import 'package:matrix/matrix.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import 'portal_avatar.dart';

/// 消息条目：对齐原型里的圆角气泡。我方右对齐，对方左侧头像。
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.event});
  final Event event;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final isMe = event.senderId == event.room.client.userID;
    final time = DateFormat('HH:mm').format(event.originServerTs);
    final bubbleColor = isMe ? t.accent : t.surfaceHigh;
    final textColor = isMe ? t.onAccent : t.text;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isMe ? 16 : 4),
      bottomRight: Radius.circular(isMe ? 4 : 16),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            PortalAvatar(seed: event.senderId, size: 28),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: radius,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Text(
                      event.body,
                      style: AppTheme.sans(size: 17, color: textColor),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      time,
                      style: AppTheme.sans(size: 11, color: t.textMute),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 输入栏：毛玻璃底栏 + 圆形输入框，对齐原型 chat-input-bar。
class MessageInputBar extends StatelessWidget {
  const MessageInputBar({
    super.key,
    required this.ctrl,
    required this.onSend,
    required this.room,
  });

  final TextEditingController ctrl;
  final VoidCallback onSend;
  final Room room;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: t.bg.withValues(alpha: 0.85),
            border: Border(
              top: BorderSide(color: t.border.withValues(alpha: 0.5)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(Symbols.add_circle, size: 26, color: t.textMute),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: t.surfaceHigh,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: ctrl,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => onSend(),
                              minLines: 1,
                              maxLines: 5,
                              style: AppTheme.sans(size: 17, color: t.text),
                              decoration: InputDecoration(
                                hintText: '消息...',
                                hintStyle: AppTheme.sans(
                                  size: 17,
                                  color: t.textMute,
                                ),
                                isCollapsed: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Symbols.sentiment_satisfied,
                              size: 22,
                              color: t.accent,
                            ),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: t.accent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onSend,
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(Symbols.send, size: 18, color: t.onAccent),
                      ),
                    ),
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
