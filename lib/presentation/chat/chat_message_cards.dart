import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../l10n/app_localizations.dart';
import 'chat_record_forwarding.dart';

const chatMessageCardWidth = 220.0;
const chatMessageCardHeight = 130.0;
const chatMessageCardTotalWidth = chatMessageCardWidth;
const chatMessageCardMaxWidthFactor = 0.77;
const chatMessageBubbleRadius = BorderRadius.all(Radius.circular(24));
const chatMessageMediaWidth = 220.0;
const chatMessageMediaHeight = 160.0;
const chatMessageImageMediaWidth = 200.0;
const chatMessageImageMediaHeight = 145.0;
const chatMessageMediaMaxWidth = 200.0;
const chatMessageMediaMaxHeight = 250.0;
const chatMessageMediaMinSide = 110.0;
const chatMessageCompactCardWidth = chatMessageCardWidth;

void _chatCardGestureLog(String message) {
  debugPrint('[chat gesture] $message');
}

class ChatMediaBubbleSize {
  const ChatMediaBubbleSize({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;
}

const chatMessageDefaultMediaSize = ChatMediaBubbleSize(
  width: chatMessageMediaWidth,
  height: chatMessageMediaHeight,
);

const chatMessageDefaultImageMediaSize = ChatMediaBubbleSize(
  width: chatMessageImageMediaWidth,
  height: chatMessageImageMediaHeight,
);

ChatMediaBubbleSize chatMediaBubbleSizeFor({
  required int width,
  required int height,
}) {
  if (width <= 0 || height <= 0) return chatMessageDefaultImageMediaSize;
  final aspect = width / height;
  if (!aspect.isFinite || aspect <= 0) return chatMessageDefaultImageMediaSize;
  if (aspect >= 1) {
    return ChatMediaBubbleSize(
      width: chatMessageMediaMaxWidth,
      height: (chatMessageMediaMaxWidth / aspect).clamp(
        chatMessageMediaMinSide,
        chatMessageMediaMaxWidth,
      ),
    );
  }
  return ChatMediaBubbleSize(
    width: (chatMessageMediaMaxHeight * aspect).clamp(
      chatMessageMediaMinSide,
      chatMessageMediaMaxWidth,
    ),
    height: chatMessageMediaMaxHeight,
  );
}

ChatMediaBubbleSize chatMediaBubbleSizeForEvent(Event event) {
  final info = event.infoMap;
  final width = _intValue(info['w'] ?? info['width']);
  final height = _intValue(info['h'] ?? info['height']);
  if (width > 0 && height > 0) {
    return chatMediaBubbleSizeFor(width: width, height: height);
  }
  final thumbnailInfo = info['thumbnail_info'];
  if (thumbnailInfo is Map) {
    final thumbnailWidth =
        _intValue(thumbnailInfo['w'] ?? thumbnailInfo['width']);
    final thumbnailHeight =
        _intValue(thumbnailInfo['h'] ?? thumbnailInfo['height']);
    if (thumbnailWidth > 0 && thumbnailHeight > 0) {
      return chatMediaBubbleSizeFor(
        width: thumbnailWidth,
        height: thumbnailHeight,
      );
    }
  }
  return chatMessageDefaultImageMediaSize;
}

int _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

BorderRadius chatDirectionalBubbleRadius(bool isMe) {
  return chatMessageBubbleRadius;
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
        child: ColoredBox(
          color: context.tk.surfaceHigh,
          child: SizedBox.expand(child: child),
        ),
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
      onTapDown: (details) {
        pressPosition = details.globalPosition;
        _chatCardGestureLog(
          'card tapDown pos=$pressPosition hasTap=${onTap != null} hasLong=${onLongPressAt != null}',
        );
      },
      onTap: () {
        _chatCardGestureLog('card tap fire hasTap=${onTap != null}');
        onTap?.call();
      },
      onLongPress: () {
        _chatCardGestureLog(
          'card longPress fire pos=$pressPosition hasLong=${onLongPressAt != null}',
        );
        onLongPressAt?.call(pressPosition);
      },
      onSecondaryTapDown: (details) {
        pressPosition = details.globalPosition;
        _chatCardGestureLog(
          'card secondaryTapDown pos=$pressPosition hasLong=${onLongPressAt != null}',
        );
      },
      onSecondaryTap: () {
        _chatCardGestureLog(
          'card secondaryTap fire pos=$pressPosition hasLong=${onLongPressAt != null}',
        );
        onLongPressAt?.call(pressPosition);
      },
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
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final titleColor = t.text;
    final secondaryColor = t.textMute;
    final dividerColor = t.border.withValues(alpha: 0.45);
    final previews = chatRecordItems(payload)
        .where((item) => _chatRecordPreviewLine(item, l10n: l10n).isNotEmpty)
        .take(3)
        .toList(growable: false);
    return ChatCardBubbleFrame(
      onTap: onTap,
      onLongPressAt: onLongPressAt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _chatRecordCardTitle(payload, l10n: l10n),
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
                for (final entry in previews.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: _ChatRecordPreviewRow(
                      key: ValueKey('chat_record_preview_row_${entry.$1}'),
                      item: entry.$2,
                      l10n: l10n,
                      color: secondaryColor,
                      avatarKey: ValueKey(
                        'chat_record_preview_avatar_${entry.$1}',
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(height: 1, color: dividerColor),
          const SizedBox(height: 5),
          Text(
            l10n?.messagePreviewChatRecord ?? '聊天记录',
            style: AppTheme.sans(size: 11, color: secondaryColor),
          ),
        ],
      ),
    );
  }
}

class _ChatRecordPreviewRow extends StatelessWidget {
  const _ChatRecordPreviewRow({
    super.key,
    required this.item,
    required this.l10n,
    required this.color,
    required this.avatarKey,
  });

  final ChatRecordItem item;
  final AppLocalizations? l10n;
  final Color color;
  final Key avatarKey;

  @override
  Widget build(BuildContext context) {
    final line = _chatRecordPreviewLine(item, l10n: l10n);
    final seed = item.senderName.trim().isNotEmpty
        ? item.senderName.trim()
        : item.senderId.trim();
    return Row(
      children: [
        _ChatRecordPreviewAvatar(key: avatarKey, seed: seed),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            line,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.sans(size: 12, color: color).copyWith(
              height: 1.12,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatRecordPreviewAvatar extends StatelessWidget {
  const _ChatRecordPreviewAvatar({super.key, required this.seed});

  final String seed;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final letter =
        seed.trim().isEmpty ? '' : seed.characters.first.toUpperCase();
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: t.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: AppTheme.sans(
          size: 8,
          weight: FontWeight.w700,
          color: t.textMute,
        ),
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
      onTapDown: (details) {
        pressPosition = details.globalPosition;
        _chatCardGestureLog(
          'callRecord tapDown pos=$pressPosition hasTap=${onTap != null} hasLong=${onLongPressAt != null}',
        );
      },
      onTap: () {
        _chatCardGestureLog('callRecord tap fire hasTap=${onTap != null}');
        onTap?.call();
      },
      onLongPress: () {
        _chatCardGestureLog(
          'callRecord longPress fire pos=$pressPosition hasLong=${onLongPressAt != null}',
        );
        onLongPressAt?.call(pressPosition);
      },
      onSecondaryTapDown: (details) {
        pressPosition = details.globalPosition;
        _chatCardGestureLog(
          'callRecord secondaryTapDown pos=$pressPosition hasLong=${onLongPressAt != null}',
        );
      },
      onSecondaryTap: () {
        _chatCardGestureLog(
          'callRecord secondaryTap fire pos=$pressPosition hasLong=${onLongPressAt != null}',
        );
        onLongPressAt?.call(pressPosition);
      },
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

class ChatVoiceBubbleContent extends StatefulWidget {
  const ChatVoiceBubbleContent({
    super.key,
    required this.isMe,
    required this.durationSeconds,
    this.isPlaying = false,
    this.currentPlaySeconds = 0,
    this.onSeek,
  });

  final bool isMe;
  final int durationSeconds;
  final bool isPlaying;
  final int currentPlaySeconds;
  final ValueChanged<int>? onSeek;

  static const _barWidth = 1.0;
  static const _barSpacing = 0.5;

  @override
  State<ChatVoiceBubbleContent> createState() => _ChatVoiceBubbleContentState();
}

class _ChatVoiceBubbleContentState extends State<ChatVoiceBubbleContent> {
  bool _dragging = false;
  double _dragProgress = 0;
  int? _lastSeekSeconds;

  int get _duration => widget.durationSeconds <= 0 ? 1 : widget.durationSeconds;
  int get _barCount => _duration.clamp(3, 60);

  double get _progress {
    if (_dragging) return _dragProgress.clamp(0, 1);
    if (!widget.isPlaying || _duration <= 0) return 0;
    return (widget.currentPlaySeconds / _duration).clamp(0, 1);
  }

  int get _activeCount {
    if (!widget.isPlaying && !_dragging) return 0;
    return (_barCount * _progress).floor().clamp(0, _barCount);
  }

  int get _displaySeconds {
    if (_dragging) {
      return (_duration - _seekSecondsForProgress(_dragProgress))
          .clamp(0, _duration);
    }
    if (!widget.isPlaying) return _duration;
    return (_duration - widget.currentPlaySeconds).clamp(0, _duration);
  }

  int _seekSecondsForProgress(double progress) {
    return (progress.clamp(0, 1) * _duration).round().clamp(0, _duration);
  }

  void _handleSeek(DragUpdateDetails details, double width) {
    final onSeek = widget.onSeek;
    if (onSeek == null || _duration <= 0) return;
    final localX = details.localPosition.dx.clamp(0, width);
    final progress = width <= 0 ? 0.0 : localX / width;
    final seconds = _seekSecondsForProgress(progress);
    setState(() {
      _dragging = true;
      _dragProgress = progress;
    });
    if (_lastSeekSeconds != seconds) {
      _lastSeekSeconds = seconds;
      onSeek(seconds);
    }
  }

  void _endSeek() {
    if (!_dragging) return;
    setState(() {
      _dragging = false;
      _lastSeekSeconds = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final foreground = widget.isMe ? t.onAccent : t.text;
    final inactive = foreground.withValues(alpha: widget.isMe ? 0.4 : 0.22);
    final children = <Widget>[
      _VoiceIcon(
        isMe: widget.isMe,
        color: foreground,
        isPlaying: widget.isPlaying,
      ),
      _VoiceWaveform(
        barCount: _barCount,
        durationSeconds: _duration,
        isMe: widget.isMe,
        activeCount: _activeCount,
        activeColor: foreground,
        inactiveColor: inactive,
      ),
      SizedBox(
        width: 33,
        child: Text(
          '${_displaySeconds}s',
          maxLines: 1,
          textAlign: TextAlign.center,
          style: AppTheme.sans(size: 14, color: foreground).copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    ];
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : (33 + _barCount * 1.5 + 24);
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: widget.onSeek == null
                ? null
                : (details) => _handleSeek(details, width),
            onHorizontalDragEnd:
                widget.onSeek == null ? null : (_) => _endSeek(),
            onHorizontalDragCancel: widget.onSeek == null ? null : _endSeek,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: widget.isMe ? children.reversed.toList() : children,
            ),
          );
        },
      ),
    );
  }
}

class _VoiceWaveform extends StatelessWidget {
  const _VoiceWaveform({
    required this.barCount,
    required this.durationSeconds,
    required this.isMe,
    required this.activeCount,
    required this.activeColor,
    required this.inactiveColor,
  });

  final int barCount;
  final int durationSeconds;
  final bool isMe;
  final int activeCount;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < barCount; i++) ...[
            Container(
              width: ChatVoiceBubbleContent._barWidth,
              height: _heightFor(i),
              decoration: BoxDecoration(
                color: i < activeCount ? activeColor : inactiveColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            if (i != barCount - 1)
              const SizedBox(width: ChatVoiceBubbleContent._barSpacing),
          ],
        ],
      ),
    );
  }

  double _heightFor(int index) {
    final seedBase = durationSeconds * 31 + (isMe ? 13 : 7);
    final seed = (seedBase ^ (index * 97)).abs();
    final normalized = (seed % 1000) / 1000;
    return 4 + normalized * 16;
  }
}

class _VoiceIcon extends StatefulWidget {
  const _VoiceIcon({
    required this.isMe,
    required this.color,
    required this.isPlaying,
  });

  final bool isMe;
  final Color color;
  final bool isPlaying;

  @override
  State<_VoiceIcon> createState() => _VoiceIconState();
}

class _VoiceIconState extends State<_VoiceIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
    lowerBound: 0.96,
    upperBound: 1.08,
  );

  @override
  void initState() {
    super.initState();
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    } else {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant _VoiceIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying == oldWidget.isPlaying) return;
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      Symbols.graphic_eq,
      size: 20,
      color: widget.color,
      fill: widget.isPlaying ? 1 : 0,
    );
    return ScaleTransition(
      scale: _controller,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(widget.isMe ? -1.0 : 1.0, 1.0, 1.0),
        child: icon,
      ),
    );
  }
}

String _chatRecordCardTitle(
  ChatRecordPayload payload, {
  AppLocalizations? l10n,
}) {
  return switch (payload.sourceRoomType) {
    'group' => l10n?.messagePreviewGroupChatRecord ?? '群聊的聊天记录',
    'direct' => l10n?.messagePreviewDirectChatRecord ?? '私聊的聊天记录',
    'channel' => l10n?.messagePreviewChannelChatRecord ?? '频道的聊天记录',
    'agent' => l10n?.messagePreviewAgentChatRecord ?? 'Agent 聊天记录',
    _ => l10n?.messagePreviewChatRecord ?? '聊天记录',
  };
}

String _chatRecordPreviewLine(ChatRecordItem item, {AppLocalizations? l10n}) {
  final sender = item.senderName.trim();
  final content = _chatRecordPreviewBody(item, l10n: l10n);
  if (content.isEmpty) return '';
  return sender.isEmpty ? content : '$sender: $content';
}

String _chatRecordPreviewBody(ChatRecordItem item, {AppLocalizations? l10n}) {
  final messageType = item.messageType.trim();
  final nested = chatRecordPayloadFromContent(item.content);
  if (nested != null) {
    return '${l10n?.messagePreviewChatRecordBracket ?? '[聊天记录]'} ${nested.title}';
  }
  if (messageType == MessageTypes.Image) {
    return l10n?.messagePreviewImageBracket ?? '[图片]';
  }
  if (messageType == MessageTypes.Video) {
    return l10n?.messagePreviewVideoBracket ?? '[视频]';
  }
  if (messageType == MessageTypes.File) {
    final name = item.filename.trim();
    final label = l10n?.messagePreviewFileBracket ?? '[文件]';
    return name.isEmpty ? label : '$label $name';
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
