import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';

const _assetChatEmoji =
    'assets/resources/chat_composer_emoji__chat_composer_emoji.svg';
const _assetChatPlus =
    'assets/resources/chat_composer_plus__chat_composer_plus.svg';
const _assetChatMore = 'assets/icons/toklink_more_vertical.svg';

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

const double _chatHeaderChromeClearance = 52;
const double _chatBottomChromeClearance = 76;
const double _chatReplyBarClearance = 54;
const double _chatSelectionBarClearance = 64;
const double _chatBottomPanelClearance = 268;
const double chatEmojiPanelDefaultHeight = 320;

const double _composerButtonSize = 40;
const double _composerFieldHeight = 40;
const double _composerFieldRadius = 22;

EdgeInsets chatMessageViewportPadding(
  BuildContext context, {
  double horizontal = 0,
  bool replyBarVisible = false,
  bool selectionBarVisible = false,
  bool bottomPanelVisible = false,
  bool reserveTopOverlay = true,
  bool reserveBottomOverlay = true,
}) {
  return EdgeInsets.fromLTRB(
    horizontal,
    reserveTopOverlay ? chatMessageTopOverlayClearance(context) : 0,
    horizontal,
    reserveBottomOverlay
        ? chatMessageBottomOverlayClearance(
            context,
            replyBarVisible: replyBarVisible,
            selectionBarVisible: selectionBarVisible,
            bottomPanelVisible: bottomPanelVisible,
          )
        : 0,
  );
}

double chatMessageTopOverlayClearance(BuildContext context) {
  final safeArea = MediaQuery.paddingOf(context);
  return safeArea.top + _chatHeaderChromeClearance;
}

double chatMessageBottomOverlayClearance(
  BuildContext context, {
  bool replyBarVisible = false,
  bool selectionBarVisible = false,
  bool bottomPanelVisible = false,
}) {
  final safeArea = MediaQuery.paddingOf(context);
  return safeArea.bottom +
      _chatBottomChromeClearance +
      (replyBarVisible ? _chatReplyBarClearance : 0) +
      (selectionBarVisible ? _chatSelectionBarClearance : 0) +
      (bottomPanelVisible ? _chatBottomPanelClearance : 0);
}

class ChatLayeredLayout extends StatelessWidget {
  const ChatLayeredLayout({
    super.key,
    required this.header,
    required this.messageLayer,
    required this.bottomOverlay,
    this.messageTopInset = 0,
    this.messageBottomInset = 0,
  });

  final Widget header;
  final Widget messageLayer;
  final Widget bottomOverlay;
  final double messageTopInset;
  final double messageBottomInset;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: t.bg,
        systemNavigationBarDividerColor: t.bg,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            top: messageTopInset,
            bottom: messageBottomInset,
            child: ClipRect(child: messageLayer),
          ),
          Align(alignment: Alignment.topCenter, child: header),
          Align(alignment: Alignment.bottomCenter, child: bottomOverlay),
        ],
      ),
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

const double _chatHeaderButtonSize = 40;
const double _chatHeaderTitleSize = 16;

enum ChatCapsuleSubtitleStatus {
  online,
  offline,
}

class ChatCapsuleHeader extends StatelessWidget {
  const ChatCapsuleHeader({
    super.key,
    required this.title,
    required this.onBack,
    required this.actions,
    this.leadingAvatar,
    this.subtitle,
    this.subtitleStatus,
    this.onAvatarTap,
    this.onTitleTap,
    this.showEncryptionIcon = false,
  });

  final String title;
  final String? subtitle;
  final ChatCapsuleSubtitleStatus? subtitleStatus;
  final VoidCallback onBack;
  final Widget? leadingAvatar;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onTitleTap;
  final List<ChatCapsuleAction> actions;
  final bool showEncryptionIcon;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final detailAction = actions.isEmpty ? null : actions.last;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: SizedBox(
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: ChatDirectionalEntrance(
                  direction: ChatEntranceDirection.top,
                  child: KeyedSubtree(
                    key: const ValueKey('chat_header_left_capsule'),
                    child: _FigmaGlassCircleButton(
                      tooltip: '返回',
                      onTap: onBack,
                      child: Icon(
                        Symbols.arrow_back,
                        size: 24,
                        color: t.text,
                      ),
                    ),
                  ),
                ),
              ),
              ChatDirectionalEntrance(
                direction: ChatEntranceDirection.top,
                delay: const Duration(milliseconds: 35),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width - 128,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (leadingAvatar != null) ...[
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onAvatarTap,
                          child: leadingAvatar,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: GestureDetector(
                          key: const ValueKey('chat_header_title_capsule'),
                          behavior: HitTestBehavior.opaque,
                          onTap: onTitleTap,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: _HeaderTextLine(
                                      text: title,
                                      baseSize: _chatHeaderTitleSize,
                                      minScale: 0.82,
                                      weight: FontWeight.w600,
                                      color: t.text,
                                    ),
                                  ),
                                  if (showEncryptionIcon) ...[
                                    const SizedBox(width: 3),
                                    Tooltip(
                                      message: '端对端加密',
                                      child: Icon(
                                        Symbols.lock,
                                        key: const ValueKey(
                                          'chat_header_encryption_lock',
                                        ),
                                        size: 13,
                                        color: t.accentCool,
                                        fill: 1,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (subtitle != null &&
                                  subtitle!.trim().isNotEmpty) ...[
                                const SizedBox(height: 2),
                                _HeaderSubtitleLine(
                                  text: subtitle!,
                                  status: subtitleStatus,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: ChatDirectionalEntrance(
                  direction: ChatEntranceDirection.top,
                  delay: const Duration(milliseconds: 70),
                  child: Row(
                    key: const ValueKey('chat_header_actions_capsule'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _FigmaGlassCircleButton(
                        tooltip: detailAction?.tooltip ?? '详情',
                        onTap: detailAction?.onTap,
                        child: _chatAsset(
                          _assetChatMore,
                          size: 17,
                          color: t.text,
                        ),
                      ),
                    ],
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

class ChatSelectionHeader extends StatelessWidget {
  const ChatSelectionHeader({
    super.key,
    required this.count,
    required this.onCancel,
  });

  final int count;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: SizedBox(
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onCancel,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Text(
                        '取消',
                        style: AppTheme.sans(
                          size: 16,
                          weight: FontWeight.w600,
                          color: t.text,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                '已选择 $count条消息',
                style: AppTheme.sans(size: 12, color: t.textMute),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderSubtitleLine extends StatelessWidget {
  const _HeaderSubtitleLine({
    required this.text,
    this.status,
  });

  final String text;
  final ChatCapsuleSubtitleStatus? status;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final status = this.status;
    if (status == null) {
      return _HeaderTextLine(
        text: text,
        baseSize: 11,
        minScale: 0.82,
        weight: FontWeight.w400,
        color: t.textMute,
      );
    }
    final dotColor = status == ChatCapsuleSubtitleStatus.online
        ? t.tertiaryFixed
        : t.textMute.withValues(alpha: 0.55);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          key: const ValueKey('chat_header_status_dot'),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: _HeaderTextLine(
            text: text,
            baseSize: 11,
            minScale: 0.82,
            weight: FontWeight.w400,
            color: t.textMute,
          ),
        ),
      ],
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
    this.onVoiceRecordStart,
    this.onVoiceRecordStop,
    this.onVoiceRecordCancel,
    this.enabled = true,
    bool? textEnabled,
    bool? sendEnabled,
    this.hintText = '',
  })  : textEnabled = textEnabled ?? enabled,
        sendEnabled = sendEnabled ?? enabled;

  final TextEditingController ctrl;
  final VoidCallback onSend;
  final VoidCallback onPlus;
  final VoidCallback onEmoji;
  final bool plusActive;
  final bool emojiActive;
  final List<String> suggestions;
  final ValueChanged<String>? onPickSuggestion;
  final VoidCallback? onVoiceRecordStart;
  final VoidCallback? onVoiceRecordStop;
  final VoidCallback? onVoiceRecordCancel;
  final bool enabled;
  final bool textEnabled;
  final bool sendEnabled;
  final String hintText;

  @override
  State<ChatCapsuleInputBar> createState() => _ChatCapsuleInputBarState();
}

class _ChatCapsuleInputBarState extends State<ChatCapsuleInputBar> {
  bool _voiceMode = false;
  bool _pressingVoice = false;
  bool _cancelVoicePressOnRelease = false;
  Offset? _voicePressStartGlobal;
  DateTime? _voicePressStartedAt;
  Duration _voiceElapsed = Duration.zero;
  Timer? _voiceElapsedTimer;
  OverlayEntry? _voiceOverlayEntry;
  final FocusNode _textFocusNode = FocusNode();

  void _focusTextInput() {
    if (!widget.textEnabled) return;
    if (widget.emojiActive) {
      widget.onEmoji();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.textEnabled) return;
        _textFocusNode.requestFocus();
      });
      return;
    }
    if (widget.plusActive) {
      widget.onPlus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.textEnabled) return;
        _textFocusNode.requestFocus();
      });
    }
  }

  void _toggleEmojiPanel() {
    if (!widget.enabled) return;
    if (widget.emojiActive) {
      _focusTextInput();
      return;
    }
    _textFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    widget.onEmoji();
  }

  void _togglePlusPanel() {
    if (!widget.enabled) return;
    if (!widget.plusActive) {
      _textFocusNode.unfocus();
      FocusManager.instance.primaryFocus?.unfocus();
    }
    widget.onPlus();
  }

  void _startVoicePress(Offset globalPosition) {
    if (!widget.enabled) return;
    if (_pressingVoice) return;
    setState(() {
      _pressingVoice = true;
      _cancelVoicePressOnRelease = false;
      _voicePressStartGlobal = globalPosition;
      _voicePressStartedAt = DateTime.now();
      _voiceElapsed = Duration.zero;
    });
    _showVoiceOverlay();
    _startVoiceElapsedTimer();
    widget.onVoiceRecordStart?.call();
  }

  void _stopVoicePress() {
    if (!_pressingVoice) return;
    final shouldCancel = _cancelVoicePressOnRelease;
    _clearVoiceOverlay();
    setState(() {
      _pressingVoice = false;
      _cancelVoicePressOnRelease = false;
      _voicePressStartGlobal = null;
      _voicePressStartedAt = null;
      _voiceElapsed = Duration.zero;
    });
    if (shouldCancel) {
      widget.onVoiceRecordCancel?.call();
    } else {
      widget.onVoiceRecordStop?.call();
    }
  }

  void _cancelVoicePress() {
    if (!_pressingVoice) return;
    _clearVoiceOverlay();
    setState(() {
      _pressingVoice = false;
      _cancelVoicePressOnRelease = false;
      _voicePressStartGlobal = null;
      _voicePressStartedAt = null;
      _voiceElapsed = Duration.zero;
    });
    widget.onVoiceRecordCancel?.call();
  }

  void _updateVoicePress(Offset globalPosition) {
    final start = _voicePressStartGlobal;
    if (!_pressingVoice || start == null) return;
    final shouldCancel = start.dy - globalPosition.dy >= 160;
    if (shouldCancel == _cancelVoicePressOnRelease) return;
    setState(() => _cancelVoicePressOnRelease = shouldCancel);
    _voiceOverlayEntry?.markNeedsBuild();
  }

  void _showVoiceOverlay() {
    if (_voiceOverlayEntry != null) {
      _voiceOverlayEntry!.markNeedsBuild();
      return;
    }
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _voiceOverlayEntry = OverlayEntry(
      builder: (_) => _VoiceRecordingOverlay(
        canceling: _cancelVoicePressOnRelease,
        elapsed: _voiceElapsed,
      ),
    );
    overlay.insert(_voiceOverlayEntry!);
  }

  void _startVoiceElapsedTimer() {
    _voiceElapsedTimer?.cancel();
    _voiceElapsedTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final startedAt = _voicePressStartedAt;
      if (!_pressingVoice || startedAt == null) return;
      _voiceElapsed = DateTime.now().difference(startedAt);
      _voiceOverlayEntry?.markNeedsBuild();
    });
  }

  void _clearVoiceOverlay() {
    _voiceElapsedTimer?.cancel();
    _voiceElapsedTimer = null;
    _voiceOverlayEntry?.remove();
    _voiceOverlayEntry = null;
  }

  @override
  void dispose() {
    _clearVoiceOverlay();
    _textFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final voicePrompt = !_pressingVoice
        ? '按住 说话'
        : _cancelVoicePressOnRelease
            ? '松开 取消'
            : '松开 发送';
    final voicePromptColor = !widget.enabled
        ? t.textMute.withValues(alpha: 0.45)
        : !_pressingVoice
            ? t.text
            : _cancelVoicePressOnRelease
                ? t.danger
                : t.accent;
    final voiceSurfaceColor = !_pressingVoice
        ? null
        : _cancelVoicePressOnRelease
            ? t.danger.withValues(alpha: 0.10)
            : t.accent.withValues(alpha: 0.10);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.bg,
        border: Border(
          top: BorderSide(color: t.border.withValues(alpha: 0.45), width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            12,
            10,
            12,
            (_shouldFlushToBottom(context) ? 0 : 12),
          ),
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
                            Icon(Symbols.auto_awesome,
                                size: 14, color: t.accent),
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
                      key: const ValueKey('chat_input_mic_circle'),
                      width: _composerButtonSize,
                      height: _composerButtonSize,
                      child: _AssetCircleCapsuleButton(
                        icon: _voiceMode ? Symbols.keyboard : Symbols.mic,
                        tooltip: _voiceMode ? '键盘' : '语音',
                        enabled: widget.enabled,
                        onTap: () => setState(() => _voiceMode = !_voiceMode),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChatDirectionalEntrance(
                      direction: ChatEntranceDirection.bottom,
                      delay: const Duration(milliseconds: 35),
                      child: ConstrainedBox(
                        key: const ValueKey('chat_input_text_capsule'),
                        constraints: const BoxConstraints(
                          minHeight: _composerFieldHeight,
                        ),
                        child: _CapsuleSurface(
                          minHeight: _composerFieldHeight,
                          height: _voiceMode ? _composerFieldHeight : null,
                          padding: EdgeInsets.zero,
                          color: _voiceMode ? voiceSurfaceColor : null,
                          borderRadius: BorderRadius.circular(
                            _composerFieldRadius,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 140),
                            child: _voiceMode
                                ? Listener(
                                    key: const ValueKey('voice_mode'),
                                    behavior: HitTestBehavior.translucent,
                                    onPointerDown: (event) =>
                                        _startVoicePress(event.position),
                                    onPointerMove: (event) =>
                                        _updateVoicePress(event.position),
                                    onPointerUp: (_) => _stopVoicePress(),
                                    onPointerCancel: (_) => _cancelVoicePress(),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: Align(
                                        alignment: Alignment.center,
                                        child: Text(
                                          voicePrompt,
                                          style: AppTheme.sans(
                                            size: 17,
                                            color: voicePromptColor,
                                            weight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : Row(
                                    key: const ValueKey('text_mode'),
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: widget.ctrl,
                                          focusNode: _textFocusNode,
                                          enabled: widget.textEnabled,
                                          onTap: _focusTextInput,
                                          textInputAction:
                                              TextInputAction.newline,
                                          maxLines: 5,
                                          minLines: 1,
                                          style: AppTheme.sans(
                                            size: 15,
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
                                              10,
                                              4,
                                              10,
                                            ),
                                            filled: false,
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChatDirectionalEntrance(
                    direction: ChatEntranceDirection.bottom,
                    delay: const Duration(milliseconds: 70),
                    child: SizedBox(
                      key: const ValueKey('chat_input_emoji_circle'),
                      width: _composerButtonSize,
                      height: _composerButtonSize,
                      child: _AssetCircleCapsuleButton(
                        assetName: widget.emojiActive ? null : _assetChatEmoji,
                        icon: widget.emojiActive ? Symbols.keyboard : null,
                        tooltip: widget.emojiActive ? '键盘' : '表情',
                        active: widget.emojiActive,
                        enabled: widget.enabled,
                        onTap: _toggleEmojiPanel,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: widget.ctrl,
                    builder: (_, value, __) {
                      final hasText = value.text.trim().isNotEmpty;
                      return ChatDirectionalEntrance(
                        direction: ChatEntranceDirection.bottom,
                        delay: const Duration(milliseconds: 90),
                        child: hasText
                            ? _ComposerSendButton(
                                key: const ValueKey('chat_input_send_button'),
                                enabled: widget.sendEnabled,
                                onTap: widget.onSend,
                              )
                            : SizedBox(
                                key: const ValueKey('chat_input_plus_circle'),
                                width: _composerButtonSize,
                                height: _composerButtonSize,
                                child: _AssetCircleCapsuleButton(
                                  assetName: _assetChatPlus,
                                  tooltip: '更多',
                                  active: widget.plusActive,
                                  enabled: widget.enabled,
                                  onTap: _togglePlusPanel,
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
      ),
    );
  }

  bool _shouldFlushToBottom(BuildContext context) {
    return widget.plusActive ||
        widget.emojiActive ||
        MediaQuery.viewInsetsOf(context).bottom > 0;
  }
}

class ChatEmojiPanel extends StatelessWidget {
  const ChatEmojiPanel({
    super.key,
    required this.onPick,
    this.height = chatEmojiPanelDefaultHeight,
  });

  final ValueChanged<String> onPick;
  final double height;

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
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(color: t.surface),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            child: GridView.count(
              physics: const BouncingScrollPhysics(),
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
      ),
    );
  }
}

class _VoiceRecordingOverlay extends StatelessWidget {
  const _VoiceRecordingOverlay({
    required this.canceling,
    required this.elapsed,
  });

  final bool canceling;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final actionColor = canceling ? t.danger : t.accent;
    return IgnorePointer(
      child: Material(
        key: const ValueKey('voice_recording_overlay'),
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: t.text.withValues(alpha: 0.70)),
            Positioned(
              left: 45,
              right: 45,
              bottom: 314,
              child: _VoiceWaveCard(
                key: const ValueKey('voice_recording_wave_card'),
                color: actionColor,
                elapsed: elapsed,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 170,
              child: CustomPaint(
                key: const ValueKey('voice_recording_release_arc'),
                painter: _VoiceReleaseArcPainter(actionColor),
              ),
            ),
            SafeArea(
              top: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 30),
                  child: Text(
                    canceling ? '松开取消' : '松开发送，上滑取消',
                    style: AppTheme.sans(
                      size: 16,
                      color: t.onAccent,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceWaveCard extends StatelessWidget {
  const _VoiceWaveCard({
    super.key,
    required this.color,
    required this.elapsed,
  });

  final Color color;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: t.text.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _VoiceWaveform(color: t.onAccent),
          const SizedBox(height: 8),
          Text(
            _formatVoiceElapsed(elapsed),
            style: AppTheme.sans(
              size: 12,
              color: t.onAccent,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceWaveform extends StatelessWidget {
  const _VoiceWaveform({required this.color});

  final Color color;

  static const _barHeights = <double>[
    14,
    20,
    10,
    18,
    26,
    12,
    30,
    16,
    24,
    11,
    18,
    13,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < _barHeights.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Container(
                width: 3,
                height: _barHeights[i],
                decoration: BoxDecoration(
                  color: color.withValues(alpha: i.isEven ? 0.52 : 0.90),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VoiceReleaseArcPainter extends CustomPainter {
  const _VoiceReleaseArcPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromLTWH(-48, 16, size.width + 96, 220),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _VoiceReleaseArcPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

String _formatVoiceElapsed(Duration elapsed) {
  final seconds = elapsed.inSeconds.clamp(0, 99 * 60 + 59);
  final minutesPart = (seconds ~/ 60).toString().padLeft(2, '0');
  final secondsPart = (seconds % 60).toString().padLeft(2, '0');
  return '$minutesPart:$secondsPart';
}

class _AssetCircleCapsuleButton extends StatelessWidget {
  const _AssetCircleCapsuleButton({
    required this.tooltip,
    required this.onTap,
    this.assetName,
    this.icon,
    this.active = false,
    this.enabled = true,
  });

  final String? assetName;
  final IconData? icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final color = t.surface;
    final iconColor = !enabled ? t.textMute.withValues(alpha: 0.42) : t.text;
    return Tooltip(
      message: tooltip,
      child: _BlurSurface(
        borderRadius: BorderRadius.circular(9999),
        color: color,
        border: Border.all(
          color: t.border.withValues(alpha: active ? 0.86 : 0.70),
          width: 0.8,
        ),
        child: Material(
          color: t.surface.withValues(alpha: 0),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? onTap : null,
            child: SizedBox(
              width: _composerButtonSize,
              height: _composerButtonSize,
              child: Center(
                child: assetName == null
                    ? Icon(icon, size: 22, color: iconColor)
                    : _chatAsset(assetName!, size: 22, color: iconColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposerSendButton extends StatelessWidget {
  const _ComposerSendButton({
    super.key,
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Tooltip(
      message: '发送',
      child: Material(
        color: enabled ? t.accent : t.textMute.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            key: const ValueKey('chat_input_send_text'),
            width: 50,
            height: 36,
            child: Center(
              child: Text(
                '发送',
                style: AppTheme.sans(
                  size: 15,
                  color: t.onAccent,
                  weight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FigmaGlassCircleButton extends StatelessWidget {
  const _FigmaGlassCircleButton({
    required this.tooltip,
    required this.child,
    this.onTap,
  });

  final String tooltip;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Tooltip(
      message: tooltip,
      child: _BlurSurface(
        borderRadius: BorderRadius.circular(9999),
        color: t.surface.withValues(alpha: 0.65),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: _chatHeaderButtonSize,
              height: _chatHeaderButtonSize,
              child: Center(child: child),
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
    this.color,
    this.borderRadius,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? height;
  final double minHeight;
  final Color? color;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(padding: padding, child: child),
    );
    final radius = borderRadius ?? BorderRadius.circular(9999);
    return _BlurSurface(
      borderRadius: radius,
      color: color ?? context.tk.surface,
      border: Border.all(
        color: context.tk.border.withValues(alpha: 0.22),
        width: 0.5,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
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
    this.border,
  });

  final Widget child;
  final Color color;
  final BorderRadius? borderRadius;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(9999);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: radius,
            border: border,
            boxShadow: [
              BoxShadow(
                color: context.tk.text.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

Widget _chatAsset(String assetName, {required double size, Color? color}) {
  if (assetName.toLowerCase().endsWith('.svg')) {
    return SvgPicture.asset(
      assetName,
      width: size,
      height: size,
      colorFilter:
          color == null ? null : ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  final image = Image.asset(
    assetName,
    width: size,
    height: size,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
  );
  if (color == null) return image;
  return ColorFiltered(
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    child: image,
  );
}
