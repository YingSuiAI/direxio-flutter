import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';

class ChatCapsuleAction {
  const ChatCapsuleAction({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;
}

enum ChatEntranceDirection { top, bottom, left, right }

class ChatInitialEntranceRegistry {
  static const closeDelay = Duration(milliseconds: 460);

  final Set<Object> _keys = {};
  bool _seeded = false;
  bool _closed = false;

  bool seed(Iterable<Object> keys) {
    if (_seeded || _closed) return false;
    final next = keys.toList(growable: false);
    if (next.isEmpty) return false;
    _seeded = true;
    _keys.addAll(next);
    return true;
  }

  void close() {
    _closed = true;
    _keys.clear();
  }

  bool contains(Object key) => !_closed && _keys.contains(key);
}

const double _chatHeaderChromeClearance = 86;
const double _chatBottomChromeClearance = 72;
const double _chatReplyBarClearance = 54;
const double _chatSelectionBarClearance = 64;
const double _chatBottomPanelClearance = 268;

EdgeInsets chatMessageViewportPadding(
  BuildContext context, {
  double horizontal = 0,
  bool replyBarVisible = false,
  bool selectionBarVisible = false,
  bool bottomPanelVisible = false,
}) {
  final safeArea = MediaQuery.paddingOf(context);
  return EdgeInsets.fromLTRB(
    horizontal,
    safeArea.top + _chatHeaderChromeClearance,
    horizontal,
    safeArea.bottom +
        _chatBottomChromeClearance +
        (replyBarVisible ? _chatReplyBarClearance : 0) +
        (selectionBarVisible ? _chatSelectionBarClearance : 0) +
        (bottomPanelVisible ? _chatBottomPanelClearance : 0),
  );
}

class ChatLayeredLayout extends StatelessWidget {
  const ChatLayeredLayout({
    super.key,
    required this.header,
    required this.messageLayer,
    required this.bottomOverlay,
  });

  final Widget header;
  final Widget messageLayer;
  final Widget bottomOverlay;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: messageLayer),
        Align(alignment: Alignment.topCenter, child: header),
        Align(alignment: Alignment.bottomCenter, child: bottomOverlay),
      ],
    );
  }
}

class ChatDirectionalEntrance extends StatefulWidget {
  const ChatDirectionalEntrance({
    super.key,
    required this.direction,
    required this.child,
    this.delay = Duration.zero,
  });

  static const duration = Duration(milliseconds: 280);

  final ChatEntranceDirection direction;
  final Widget child;
  final Duration delay;

  @override
  State<ChatDirectionalEntrance> createState() =>
      _ChatDirectionalEntranceState();
}

class _ChatDirectionalEntranceState extends State<ChatDirectionalEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<Offset> _offset;
  late Animation<double> _opacity;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: ChatDirectionalEntrance.duration,
    );
    _configureAnimations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _controller.value = 1;
      return;
    }
    if (_controller.value == 0 && !_controller.isAnimating) {
      if (widget.delay == Duration.zero) {
        _controller.forward();
      } else {
        _delayTimer ??= Timer(widget.delay, () {
          if (mounted) _controller.forward();
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant ChatDirectionalEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.direction != widget.direction) {
      _configureAnimations();
    }
  }

  void _configureAnimations() {
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _offset = Tween<Offset>(
      begin: _beginOffset(widget.direction),
      end: Offset.zero,
    ).animate(curve);
    _opacity = Tween<double>(begin: 0, end: 1).animate(curve);
  }

  Offset _beginOffset(ChatEntranceDirection direction) {
    return switch (direction) {
      ChatEntranceDirection.top => const Offset(0, -0.28),
      ChatEntranceDirection.bottom => const Offset(0, 0.28),
      ChatEntranceDirection.left => const Offset(-0.18, 0),
      ChatEntranceDirection.right => const Offset(0.18, 0),
    };
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: widget.child,
      ),
    );
  }
}

class ChatTimelineListMotion extends StatefulWidget {
  const ChatTimelineListMotion({
    super.key,
    required this.itemCount,
    required this.newestItemKey,
    required this.child,
  });

  static const duration = Duration(milliseconds: 180);

  final int itemCount;
  final Object? newestItemKey;
  final Widget child;

  @override
  State<ChatTimelineListMotion> createState() => _ChatTimelineListMotionState();
}

class _ChatTimelineListMotionState extends State<ChatTimelineListMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offset;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: ChatTimelineListMotion.duration,
      value: 1,
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.035),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(covariant ChatTimelineListMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hasNewNewest = widget.newestItemKey != null &&
        widget.newestItemKey != oldWidget.newestItemKey;
    final itemCountIncreased = widget.itemCount > oldWidget.itemCount;
    if (!_initialized) return;
    if (hasNewNewest && itemCountIncreased) {
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
        _controller.value = 1;
      } else {
        _controller
          ..value = 0
          ..forward();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initialized = true;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
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
    return SlideTransition(
      key: const ValueKey('chat_timeline_list_motion_slide'),
      position: _offset,
      child: widget.child,
    );
  }
}

Widget chatMessageEntrance({
  Key? key,
  required bool isMe,
  required int index,
  required Widget child,
  bool enabled = true,
}) {
  if (!enabled) return child;
  final delayMs = index < 8 ? index * 18 : 144;
  return ChatDirectionalEntrance(
    key: key,
    direction: isMe ? ChatEntranceDirection.right : ChatEntranceDirection.left,
    delay: Duration(milliseconds: delayMs),
    child: child,
  );
}

const double _chatHeaderCapsuleHeight = 48;
const double _chatHeaderSideCapsuleWidth = 100;
const double _chatHeaderTitleSize = 18;
const double _chatHeaderSubtitleSize = 11.7;

class ChatCapsuleHeader extends StatelessWidget {
  const ChatCapsuleHeader({
    super.key,
    required this.title,
    required this.onBack,
    required this.leadingAvatar,
    required this.actions,
    this.subtitle,
    this.onAvatarTap,
    this.onTitleTap,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  final Widget leadingAvatar;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onTitleTap;
  final List<ChatCapsuleAction> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final titleText = _HeaderTextLine(
      text: title,
      baseSize: _chatHeaderTitleSize,
      minScale: 0.82,
      weight: FontWeight.w700,
      color: t.text,
    );
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              ChatDirectionalEntrance(
                direction: ChatEntranceDirection.top,
                child: SizedBox(
                  key: const ValueKey('chat_header_left_capsule'),
                  width: _chatHeaderSideCapsuleWidth,
                  height: _chatHeaderCapsuleHeight,
                  child: _CapsuleSurface(
                    height: _chatHeaderCapsuleHeight,
                    minHeight: _chatHeaderCapsuleHeight,
                    padding: EdgeInsets.zero,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: '返回',
                          icon: const Icon(
                            Symbols.arrow_back_ios_new,
                            size: 23,
                          ),
                          color: t.text,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 44,
                            height: _chatHeaderCapsuleHeight,
                          ),
                          onPressed: onBack,
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onAvatarTap,
                          child: leadingAvatar,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChatDirectionalEntrance(
                  direction: ChatEntranceDirection.top,
                  delay: const Duration(milliseconds: 35),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTitleTap,
                    child: SizedBox(
                      key: const ValueKey('chat_header_title_capsule'),
                      height: _chatHeaderCapsuleHeight,
                      child: _CapsuleSurface(
                        height: _chatHeaderCapsuleHeight,
                        minHeight: _chatHeaderCapsuleHeight,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: SizedBox(
                          width: double.infinity,
                          child: Center(
                            child: subtitle == null || subtitle!.trim().isEmpty
                                ? titleText
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      titleText,
                                      const SizedBox(height: 1),
                                      _HeaderTextLine(
                                        text: subtitle!,
                                        baseSize: _chatHeaderSubtitleSize,
                                        minScale: 0.82,
                                        color: t.textMute,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ChatDirectionalEntrance(
                direction: ChatEntranceDirection.top,
                delay: const Duration(milliseconds: 70),
                child: SizedBox(
                  key: const ValueKey('chat_header_actions_capsule'),
                  width: _chatHeaderSideCapsuleWidth,
                  height: _chatHeaderCapsuleHeight,
                  child: _CapsuleSurface(
                    height: _chatHeaderCapsuleHeight,
                    minHeight: _chatHeaderCapsuleHeight,
                    padding: EdgeInsets.zero,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: actions
                          .take(2)
                          .map(
                            (action) => IconButton(
                              tooltip: action.tooltip,
                              icon: Icon(action.icon, size: 23),
                              color: action.color ?? t.accent,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                width: 36,
                                height: _chatHeaderCapsuleHeight,
                              ),
                              onPressed: action.onTap,
                            ),
                          )
                          .toList(growable: false),
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

class _HeaderTextLine extends StatelessWidget {
  const _HeaderTextLine({
    required this.text,
    required this.baseSize,
    required this.minScale,
    required this.color,
    this.weight = FontWeight.w400,
  });

  final String text;
  final double baseSize;
  final double minScale;
  final Color color;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var size = baseSize;
        final maxWidth = constraints.maxWidth;
        if (maxWidth.isFinite && maxWidth > 0) {
          final baseStyle = AppTheme.sans(
            size: baseSize,
            weight: weight,
            color: color,
          );
          final painter = TextPainter(
            text: TextSpan(text: text, style: baseStyle),
            maxLines: 1,
            textDirection: Directionality.of(context),
          )..layout(maxWidth: double.infinity);
          if (painter.width > maxWidth && painter.width > 0) {
            final scale =
                (maxWidth / painter.width).clamp(minScale, 1.0).toDouble();
            size = baseSize * scale;
          }
        }
        return Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTheme.sans(size: size, weight: weight, color: color),
        );
      },
    );
  }
}

class ChatCapsuleInputBar extends StatefulWidget {
  const ChatCapsuleInputBar({
    super.key,
    required this.ctrl,
    required this.onSend,
    required this.onPlus,
    required this.onEmoji,
    this.plusActive = false,
    this.emojiActive = false,
    this.suggestions = const [],
    this.onPickSuggestion,
    this.enabled = true,
    this.hintText = '消息…',
  });

  final TextEditingController ctrl;
  final VoidCallback onSend;
  final VoidCallback onPlus;
  final VoidCallback onEmoji;
  final bool plusActive;
  final bool emojiActive;
  final List<String> suggestions;
  final ValueChanged<String>? onPickSuggestion;
  final bool enabled;
  final String hintText;

  @override
  State<ChatCapsuleInputBar> createState() => _ChatCapsuleInputBarState();
}

class _ChatCapsuleInputBarState extends State<ChatCapsuleInputBar> {
  bool _voiceMode = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.suggestions.isNotEmpty)
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 6),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Row(
                        children: [
                          Icon(Symbols.auto_awesome, size: 14, color: t.accent),
                          const SizedBox(width: 4),
                          Text(
                            'AI 建议',
                            style: AppTheme.sans(
                              size: 12,
                              color: t.textMute,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...widget.suggestions.map(
                      (suggestion) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _CapsuleSurface(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          height: 30,
                          onTap: () => widget.onPickSuggestion?.call(
                            suggestion,
                          ),
                          child: Center(
                            child: Text(
                              suggestion,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.sans(size: 13, color: t.text),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ChatDirectionalEntrance(
                  direction: ChatEntranceDirection.bottom,
                  child: SizedBox(
                    key: const ValueKey('chat_input_plus_circle'),
                    width: 46,
                    height: 46,
                    child: _CircleCapsuleButton(
                      icon: Symbols.add,
                      tooltip: '更多',
                      active: widget.plusActive,
                      enabled: widget.enabled,
                      onTap: widget.onPlus,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChatDirectionalEntrance(
                    direction: ChatEntranceDirection.bottom,
                    delay: const Duration(milliseconds: 35),
                    child: ConstrainedBox(
                      key: const ValueKey('chat_input_text_capsule'),
                      constraints: const BoxConstraints(minHeight: 46),
                      child: _CapsuleSurface(
                        minHeight: 46,
                        padding: EdgeInsets.zero,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 140),
                          child: _voiceMode
                              ? GestureDetector(
                                  key: const ValueKey('voice_mode'),
                                  behavior: HitTestBehavior.opaque,
                                  onLongPressStart: (_) {},
                                  onLongPressEnd: (_) {},
                                  child: Center(
                                    child: Text(
                                      '按住发语音',
                                      style: AppTheme.sans(
                                        size: 17,
                                        color: widget.enabled
                                            ? t.text
                                            : t.textMute
                                                .withValues(alpha: 0.45),
                                        weight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                )
                              : Row(
                                  key: const ValueKey('text_mode'),
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: widget.ctrl,
                                        enabled: widget.enabled,
                                        textInputAction:
                                            TextInputAction.newline,
                                        maxLines: 5,
                                        minLines: 1,
                                        style: AppTheme.sans(
                                          size: 17,
                                          color: t.text,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: widget.hintText,
                                          hintStyle: AppTheme.sans(
                                            size: 17,
                                            color: t.textMute,
                                          ),
                                          isCollapsed: true,
                                          contentPadding:
                                              const EdgeInsets.fromLTRB(
                                            16,
                                            12,
                                            4,
                                            12,
                                          ),
                                          filled: false,
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(right: 5),
                                      child: _CircleCapsuleButton(
                                        icon: Symbols.mood,
                                        tooltip: '表情',
                                        active: widget.emojiActive,
                                        enabled: widget.enabled,
                                        compact: true,
                                        onTap: widget.onEmoji,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: widget.ctrl,
                  builder: (_, value, __) {
                    final hasText = value.text.trim().isNotEmpty;
                    final icon = hasText
                        ? Symbols.arrow_upward
                        : _voiceMode
                            ? Symbols.keyboard
                            : Symbols.mic;
                    return ChatDirectionalEntrance(
                      direction: ChatEntranceDirection.bottom,
                      delay: const Duration(milliseconds: 70),
                      child: SizedBox(
                        key: const ValueKey('chat_input_mic_circle'),
                        width: 46,
                        height: 46,
                        child: _CircleCapsuleButton(
                          icon: icon,
                          tooltip: hasText
                              ? '发送'
                              : _voiceMode
                                  ? '切换键盘'
                                  : '语音',
                          accent: hasText,
                          enabled: widget.enabled,
                          onTap: hasText
                              ? widget.onSend
                              : () => setState(() => _voiceMode = !_voiceMode),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ChatEmojiPanel extends StatelessWidget {
  const ChatEmojiPanel({super.key, required this.onPick});

  final ValueChanged<String> onPick;

  static const _emojis = [
    '😀',
    '😂',
    '🥲',
    '😍',
    '🥰',
    '😘',
    '😭',
    '😤',
    '👍',
    '❤️',
    '🙏',
    '💪',
    '👏',
    '✌️',
    '🤝',
    '🫡',
    '🎉',
    '🔥',
    '💯',
    '✨',
    '😅',
    '😆',
    '🤣',
    '😋',
    '😎',
    '🤓',
    '🤗',
    '😏',
    '😢',
    '😡',
    '🥹',
    '🫶',
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return _BlurSurface(
      color: t.surface.withValues(alpha: 0.62),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 8,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: _emojis
                .map(
                  (emoji) => Material(
                    color: t.surface.withValues(alpha: 0),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => onPick(emoji),
                      child: Center(
                        child: Text(emoji, style: AppTheme.sans(size: 24)),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _CircleCapsuleButton extends StatelessWidget {
  const _CircleCapsuleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
    this.accent = false,
    this.enabled = true,
    this.compact = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;
  final bool accent;
  final bool enabled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final size = compact ? 36.0 : 46.0;
    final iconSize = compact ? 22.0 : 25.0;
    final color = accent
        ? t.accent
        : active
            ? t.primaryContainer.withValues(alpha: 0.24)
            : t.surface.withValues(alpha: 0.70);
    final iconColor = !enabled
        ? t.textMute.withValues(alpha: 0.42)
        : accent
            ? t.onAccent
            : active
                ? t.accent
                : t.text;
    return Tooltip(
      message: tooltip,
      child: _BlurSurface(
        borderRadius: BorderRadius.circular(9999),
        color: color,
        child: Material(
          color: t.surface.withValues(alpha: 0),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? onTap : null,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, size: iconSize, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}

class _CapsuleSurface extends StatelessWidget {
  const _CapsuleSurface({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
    this.height,
    this.minHeight = 46,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? height;
  final double minHeight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(padding: padding, child: child),
    );
    return _BlurSurface(
      borderRadius: BorderRadius.circular(9999),
      color: t.surface.withValues(alpha: 0.70),
      child: Material(
        color: t.surface.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(9999),
        child: InkWell(
          borderRadius: BorderRadius.circular(9999),
          onTap: onTap,
          child: height == null
              ? content
              : SizedBox(height: height, child: content),
        ),
      ),
    );
  }
}

class _BlurSurface extends StatelessWidget {
  const _BlurSurface({
    required this.child,
    required this.color,
    this.borderRadius,
  });

  final Widget child;
  final Color color;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final radius = borderRadius ?? BorderRadius.circular(9999);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: radius,
            border: Border.all(color: t.border.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                color: t.text.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
