import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import 'chat_record_forwarding.dart';

const chatMessageCardWidth = 220.0;
const chatMessageCardHeight = 130.0;
const chatMessageCardTotalWidth = chatMessageCardWidth;
const chatMessageCardMaxWidthFactor = 0.77;
const chatMessageBubbleRadius = BorderRadius.all(Radius.circular(24));
const chatMessageMediaWidth = 220.0;
const chatMessageMediaHeight = 160.0;
const chatMessageCompactCardWidth = chatMessageCardWidth;

BorderRadius chatDirectionalBubbleRadius(bool isMe) {
  return isMe
      ? const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(2),
        )
      : const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
          bottomLeft: Radius.circular(2),
          bottomRight: Radius.circular(24),
        );
}

class ChatBubbleFrame extends StatelessWidget {
  const ChatBubbleFrame({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class ChatMediaBubbleFrame extends StatelessWidget {
  const ChatMediaBubbleFrame({
    super.key,
    required this.width,
    required this.height,
    required this.child,
  });

  final double width;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: chatMessageBubbleRadius,
        child: SizedBox.expand(child: child),
      ),
    );
  }
}

class ChatCardBubbleFrame extends StatelessWidget {
  const ChatCardBubbleFrame({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPressAt,
  });

  final Widget child;
  final VoidCallback? onTap;
  final ValueChanged<Offset>? onLongPressAt;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final color = t.surfaceHigh;
    var pressPosition = Offset.zero;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) => pressPosition = details.globalPosition,
      onTap: onTap,
      onLongPress: () => onLongPressAt?.call(pressPosition),
      onSecondaryTapDown: (details) => pressPosition = details.globalPosition,
      onSecondaryTap: () => onLongPressAt?.call(pressPosition),
      child: SizedBox(
        width: chatMessageCompactCardWidth,
        height: chatMessageCardHeight,
        child: ChatBubbleFrame(
          child: Container(
            width: chatMessageCompactCardWidth,
            height: chatMessageCardHeight,
            padding: const EdgeInsets.fromLTRB(13, 10, 13, 9),
            decoration: BoxDecoration(
              color: color,
              borderRadius: chatMessageBubbleRadius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class ChatRecordPreviewCard extends StatelessWidget {
  const ChatRecordPreviewCard({
    super.key,
    required this.payload,
    this.onTap,
    this.onLongPressAt,
  });

  final ChatRecordPayload payload;
  final VoidCallback? onTap;
  final ValueChanged<Offset>? onLongPressAt;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final titleColor = t.text;
    final secondaryColor = t.textMute;
    final dividerColor = t.border.withValues(alpha: 0.45);
    final previews = chatRecordItems(payload)
        .take(3)
        .map(_chatRecordPreviewLine)
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    return ChatCardBubbleFrame(
      onTap: onTap,
      onLongPressAt: onLongPressAt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _chatRecordCardTitle(payload),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.sans(
              size: 16,
              weight: FontWeight.w600,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in previews)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: Text(
                      line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.sans(
                        size: 12,
                        color: secondaryColor,
                      ).copyWith(height: 1.12),
                    ),
                  ),
              ],
            ),
          ),
          Container(height: 1, color: dividerColor),
          const SizedBox(height: 5),
          Text(
            '聊天记录',
            style: AppTheme.sans(size: 11, color: secondaryColor),
          ),
        ],
      ),
    );
  }
}

class ChatCallRecordBubble extends StatelessWidget {
  const ChatCallRecordBubble({
    super.key,
    required this.isMe,
    required this.isVideo,
    required this.text,
    this.selected = false,
    this.onTap,
    this.onLongPressAt,
  });

  final bool isMe;
  final bool isVideo;
  final String text;
  final bool selected;
  final VoidCallback? onTap;
  final ValueChanged<Offset>? onLongPressAt;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final color = selected
        ? t.accent.withValues(alpha: 0.18)
        : isMe
            ? t.accent
            : t.surfaceHigh;
    final foreground = selected
        ? t.text
        : isMe
            ? t.onAccent
            : t.text;
    var pressPosition = Offset.zero;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) => pressPosition = details.globalPosition,
      onTap: onTap,
      onLongPress: () => onLongPressAt?.call(pressPosition),
      onSecondaryTapDown: (details) => pressPosition = details.globalPosition,
      onSecondaryTap: () => onLongPressAt?.call(pressPosition),
      child: ChatBubbleFrame(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: chatMessageBubbleRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isVideo ? Symbols.videocam : Symbols.call,
                size: 20,
                color: foreground,
              ),
              const SizedBox(width: 8),
              Text(
                text,
                style: AppTheme.sans(
                  size: 17,
                  weight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _chatRecordCardTitle(ChatRecordPayload payload) {
  return switch (payload.sourceRoomType) {
    'group' => '群聊的聊天记录',
    'direct' => '私聊的聊天记录',
    'channel' => '频道的聊天记录',
    'agent' => 'Agent 聊天记录',
    _ => '聊天记录',
  };
}

String _chatRecordPreviewLine(ChatRecordItem item) {
  final sender = item.senderName.trim();
  final content = _chatRecordPreviewBody(item);
  if (content.isEmpty) return '';
  return sender.isEmpty ? content : '$sender: $content';
}

String _chatRecordPreviewBody(ChatRecordItem item) {
  final messageType = item.messageType.trim();
  final nested = chatRecordPayloadFromContent(item.content);
  if (nested != null) return '[聊天记录] ${nested.title}';
  if (messageType == MessageTypes.Image) return '[图片]';
  if (messageType == MessageTypes.Video) return '[视频]';
  if (messageType == MessageTypes.File) {
    final name = item.filename.trim();
    return name.isEmpty ? '[文件]' : '[文件] $name';
  }
  return item.body.replaceAll(RegExp(r'\s+'), ' ').trim();
}

class ChatGroupAvatarTile extends StatelessWidget {
  const ChatGroupAvatarTile({
    super.key,
    required this.seed,
    this.size = 46,
  });

  final String seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final letter =
        seed.trim().isEmpty ? '' : seed.characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: t.accentCool.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.accentCool.withValues(alpha: 0.22)),
      ),
      alignment: Alignment.center,
      child: letter.isEmpty
          ? Icon(Symbols.groups, size: size * 0.52, color: t.accentCool)
          : Text(
              letter,
              style: AppTheme.sans(
                size: size * 0.40,
                weight: FontWeight.w700,
                color: t.accentCool,
              ),
            ),
    );
  }
}
