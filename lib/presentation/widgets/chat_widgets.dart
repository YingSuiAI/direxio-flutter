import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:matrix/matrix.dart';
import 'package:intl/intl.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';

/// 消息条目：侧线 + 段落（不是气泡）。我方右对齐，对方左对齐。
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.event});
  final Event event;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final isMe = event.senderId == event.room.client.userID;
    final time = DateFormat('HH:mm').format(event.originServerTs);
    final sideColor = isMe ? t.accent : t.accentCool;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMe) _SideLine(color: sideColor),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: isMe ? 12 : 12, vertical: 2),
                    child: Text(
                      event.body,
                      style: AppTheme.sans(
                          size: 14, color: t.text, weight: FontWeight.w400),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(time,
                        style: AppTheme.mono(size: 10, color: t.textMute)),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) _SideLine(color: sideColor),
        ],
      ),
    );
  }
}

class _SideLine extends StatelessWidget {
  const _SideLine({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      constraints: const BoxConstraints(minHeight: 24, maxHeight: 80),
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

/// 输入栏：方角，发送键 accent 高亮。
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
    return Container(
      decoration: BoxDecoration(
        color: t.bg,
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  decoration: InputDecoration(
                    hintText: '发消息...',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    fillColor: t.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: t.border),
                    ),
                  ),
                  style: AppTheme.sans(size: 14, color: t.text),
                  minLines: 1,
                  maxLines: 5,
                  onSubmitted: (_) => onSend(),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: t.accent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onSend,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(LucideIcons.send,
                        size: 18,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF052e16)
                            : Colors.white),
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
