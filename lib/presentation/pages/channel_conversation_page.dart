import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../channel/channel_info_data.dart';
import '../widgets/m3/glass_header.dart';
import '../widgets/portal_avatar.dart';

class ChannelConversationPage extends ConsumerStatefulWidget {
  const ChannelConversationPage({super.key, required this.channelId});

  final String channelId;

  @override
  ConsumerState<ChannelConversationPage> createState() =>
      _ChannelConversationPageState();
}

class _ChannelConversationPageState
    extends ConsumerState<ChannelConversationPage> {
  List<_ChannelConversationMessage>? _messages;

  @override
  void didUpdateWidget(covariant ChannelConversationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channelId != widget.channelId) {
      _messages = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final channel = resolveChannelInfoData(ref, widget.channelId);
    final messages = _messages ??= _initialMessages(channel.id);
    return Scaffold(
      backgroundColor: context.tk.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 76, 16, 96),
                children: [
                  Center(
                    child: Container(
                      width: 91,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.tk.surfaceHover,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '频道已创建',
                        style: AppTheme.sans(
                          size: 13,
                          weight: FontWeight.w500,
                          color: context.tk.textMute,
                        ).copyWith(height: 18 / 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 38),
                  for (var index = 0; index < messages.length; index++) ...[
                    _ChannelMessageRow(
                      message: messages[index],
                      placement: _messageMenuPlacement(index, messages.length),
                      onLongPress: (anchor) =>
                          _showMessageActions(messages[index], anchor),
                    ),
                    if (index != messages.length - 1)
                      const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: _ConversationTopBar(
                title: '#${channel.name}',
                onBack: () => context.pop(),
                onMore: () => context.push(
                  '/channel/${Uri.encodeComponent(channel.id)}/info',
                ),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _ConversationWriteBar(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMessageActions(
    _ChannelConversationMessage message,
    _ChannelMessageMenuAnchor anchor,
  ) async {
    final action = await _showChannelMessageActionMenu(
      context,
      anchor,
      placement: _messageMenuPlacement(
        (_messages ?? const <_ChannelConversationMessage>[]).indexWhere(
          (item) => item.id == message.id,
        ),
        (_messages ?? const <_ChannelConversationMessage>[]).length,
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _ChannelMessageAction.copy:
        await Clipboard.setData(ClipboardData(text: message.body));
        if (!mounted) return;
        _showSnack('已复制');
      case _ChannelMessageAction.delete:
        setState(() {
          _messages = [
            for (final item
                in _messages ?? const <_ChannelConversationMessage>[])
              if (item.id != message.id) item,
          ];
        });
        _showSnack('已删除');
      case _ChannelMessageAction.quote:
        _showSnack('已引用');
      case _ChannelMessageAction.favorite:
        _showSnack('已收藏');
      case _ChannelMessageAction.forward:
        _showSnack('转发功能即将接入频道真实消息');
      case _ChannelMessageAction.multi:
        _showSnack('多选功能即将接入频道真实消息');
    }
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 1)),
    );
  }
}

List<_ChannelConversationMessage> _initialMessages(String channelId) {
  return [
    _ChannelConversationMessage(
      id: '$channelId-message-1',
      name: 'Alice',
      time: '10:55',
      body: '我正在考虑接受它！！',
      avatarSeed: '$channelId-alice-1',
    ),
    _ChannelConversationMessage(
      id: '$channelId-message-2',
      name: 'Alice',
      time: '10:56',
      body: '我正在考虑接受它！！',
      avatarSeed: '$channelId-alice-2',
    ),
  ];
}

class _ChannelConversationMessage {
  const _ChannelConversationMessage({
    required this.id,
    required this.name,
    required this.time,
    required this.body,
    required this.avatarSeed,
  });

  final String id;
  final String name;
  final String time;
  final String body;
  final String avatarSeed;
}

class _ConversationTopBar extends StatelessWidget {
  const _ConversationTopBar({
    required this.title,
    required this.onBack,
    required this.onMore,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 16,
            top: 4,
            child: GlassHeaderButton(
              icon: Symbols.arrow_back,
              iconSize: 22,
              color: context.tk.text,
              onTap: onBack,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.sans(
                  size: 20,
                  weight: FontWeight.w600,
                  color: context.tk.text,
                ).copyWith(height: 33 / 20),
              ),
            ],
          ),
          Positioned(
            right: 16,
            top: 4,
            child: GlassHeaderButton(
              icon: Symbols.more_vert,
              iconSize: 23,
              color: context.tk.text,
              onTap: onMore,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelMessageRow extends StatelessWidget {
  const _ChannelMessageRow({
    required this.message,
    required this.placement,
    required this.onLongPress,
  });

  final _ChannelConversationMessage message;
  final _ChannelMessageMenuPlacement placement;
  final ValueChanged<_ChannelMessageMenuAnchor> onLongPress;

  @override
  Widget build(BuildContext context) {
    final bubbleKey = GlobalKey();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PortalAvatar(
          seed: message.avatarSeed,
          size: 40,
          shape: AvatarShape.squircle,
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  message.name,
                  style: AppTheme.sans(
                    size: 16,
                    weight: FontWeight.w600,
                    color: context.tk.text,
                  ).copyWith(height: 18 / 16),
                ),
                const SizedBox(width: 6),
                Text(
                  message.time,
                  style: AppTheme.sans(size: 12, color: context.tk.textMute),
                ),
              ],
            ),
            const SizedBox(height: 6),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPressStart: (details) => onLongPress(
                _channelMessageAnchorFor(
                  bubbleKey,
                  details.globalPosition,
                ),
              ),
              onSecondaryTapDown: (details) => onLongPress(
                _channelMessageAnchorFor(
                  bubbleKey,
                  details.globalPosition,
                ),
              ),
              child: Container(
                key: bubbleKey,
                height: 42,
                constraints: const BoxConstraints(minWidth: 174),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.tk.surfaceHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  message.body,
                  style: AppTheme.sans(
                    size: 15,
                    weight: FontWeight.w600,
                    color: context.tk.text,
                  ).copyWith(height: 23 / 15),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

enum _ChannelMessageAction { copy, forward, favorite, delete, multi, quote }

class _ChannelMessageMenuAnchor {
  const _ChannelMessageMenuAnchor({
    required this.position,
    this.bubbleRect,
  });

  final Offset position;
  final Rect? bubbleRect;
}

enum _ChannelMessageMenuPlacement { above, below }

_ChannelMessageMenuAnchor _channelMessageAnchorFor(
  GlobalKey key,
  Offset position,
) {
  final renderObject = key.currentContext?.findRenderObject();
  if (renderObject is RenderBox && renderObject.hasSize) {
    return _ChannelMessageMenuAnchor(
      position: position,
      bubbleRect: renderObject.localToGlobal(Offset.zero) & renderObject.size,
    );
  }
  return _ChannelMessageMenuAnchor(position: position);
}

_ChannelMessageMenuPlacement _messageMenuPlacement(
  int visualIndex,
  int messageCount,
) {
  if (visualIndex <= 0) return _ChannelMessageMenuPlacement.below;
  if (messageCount > 0 && visualIndex == messageCount - 1) {
    return _ChannelMessageMenuPlacement.above;
  }
  return _ChannelMessageMenuPlacement.below;
}

Future<_ChannelMessageAction?> _showChannelMessageActionMenu(
  BuildContext context,
  _ChannelMessageMenuAnchor anchor, {
  required _ChannelMessageMenuPlacement placement,
}) async {
  FocusScope.of(context).unfocus();
  FocusManager.instance.primaryFocus?.unfocus();
  await Future<void>.delayed(const Duration(milliseconds: 80));
  if (!context.mounted) return null;
  final size = MediaQuery.of(context).size;
  final pos = anchor.position;
  final bubbleRect = anchor.bubbleRect;
  return showGeneralDialog<_ChannelMessageAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'channel-msg-ctx',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (dialogContext, _, __) {
      const horizontalMargin = 16.0;
      final menuWidth = math.min(343.0, size.width - horizontalMargin * 2);
      const menuHeight = 168.0;
      const menuVisibleHeight = 169.0;
      const bubbleGap = 10.0;
      var left = pos.dx - menuWidth / 2;
      final pointerOnTop = placement == _ChannelMessageMenuPlacement.below;
      final bubbleEdge = pointerOnTop
          ? bubbleRect?.bottom ?? pos.dy
          : bubbleRect?.top ?? pos.dy;
      var top = pointerOnTop
          ? bubbleEdge + bubbleGap
          : bubbleEdge - menuVisibleHeight - bubbleGap;
      if (left < horizontalMargin) left = horizontalMargin;
      if (left + menuWidth > size.width - horizontalMargin) {
        left = size.width - menuWidth - horizontalMargin;
      }
      top = top.clamp(12.0, math.max(12.0, size.height - menuHeight - 12));
      final pointerX = (pos.dx - left - 10).clamp(18.0, menuWidth - 38.0);
      return SizedBox.expand(
        child: Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: menuWidth,
              height: menuHeight,
              child: _ChannelMessageActionMenuCard(
                pointerX: pointerX,
                pointerOnTop: pointerOnTop,
              ),
            ),
          ],
        ),
      );
    },
    transitionBuilder: (_, animation, __, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

class _ChannelMessageActionMenuCard extends StatelessWidget {
  const _ChannelMessageActionMenuCard({
    required this.pointerX,
    required this.pointerOnTop,
  });

  final double pointerX;
  final bool pointerOnTop;

  @override
  Widget build(BuildContext context) {
    const dark = Color(0xFF4A4A4A); // theme-fixed: Figma menu surface
    const divider = Color(0x17FFFFFF); // theme-fixed: Figma row divider
    const itemWidth = 68.6;
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        height: 168,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: pointerOnTop ? 10 : 0,
              height: 158,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: dark,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Stack(
                  children: [
                    Positioned(
                      left: 16,
                      right: 16,
                      top: 78,
                      child: Divider(height: 1, thickness: 1, color: divider),
                    ),
                    Positioned(
                      left: 0,
                      top: 12,
                      right: 0,
                      height: 58,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ChannelMessageActionMenuItem(
                            width: itemWidth,
                            icon: Symbols.content_copy,
                            label: '复制',
                            action: _ChannelMessageAction.copy,
                          ),
                          _ChannelMessageActionMenuItem(
                            width: itemWidth,
                            icon: Symbols.forward,
                            label: '转发',
                            action: _ChannelMessageAction.forward,
                          ),
                          _ChannelMessageActionMenuItem(
                            width: itemWidth,
                            icon: Symbols.bookmark,
                            label: '收藏',
                            action: _ChannelMessageAction.favorite,
                          ),
                          _ChannelMessageActionMenuItem(
                            width: itemWidth,
                            icon: Symbols.delete,
                            label: '删除',
                            action: _ChannelMessageAction.delete,
                          ),
                          _ChannelMessageActionMenuItem(
                            width: itemWidth,
                            icon: Symbols.format_list_bulleted,
                            label: '多选',
                            action: _ChannelMessageAction.multi,
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 1,
                      top: 87,
                      width: 69,
                      height: 58,
                      child: _ChannelMessageActionMenuItem(
                        width: 69,
                        icon: Symbols.format_quote_rounded,
                        label: '引用',
                        action: _ChannelMessageAction.quote,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: pointerX,
              top: pointerOnTop ? 0 : 157,
              width: 20,
              height: 12,
              child: CustomPaint(
                painter: _ChannelMessageMenuPointerPainter(
                  color: dark,
                  pointsDown: !pointerOnTop,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelMessageActionMenuItem extends StatelessWidget {
  const _ChannelMessageActionMenuItem({
    required this.width,
    required this.icon,
    required this.label,
    required this.action,
  });

  final double width;
  final IconData icon;
  final String label;
  final _ChannelMessageAction action;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 58,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).pop(action),
          borderRadius: BorderRadius.circular(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: Colors.white, fill: 0),
              const SizedBox(height: 4),
              SizedBox(
                height: 24,
                child: Center(
                  child: Text(
                    label,
                    style: AppTheme.sans(
                      size: 15,
                      weight: FontWeight.w500,
                      color: Colors.white,
                    ).copyWith(height: 20 / 15),
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

class _ChannelMessageMenuPointerPainter extends CustomPainter {
  const _ChannelMessageMenuPointerPainter({
    required this.color,
    required this.pointsDown,
  });

  final Color color;
  final bool pointsDown;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (pointsDown) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close();
    } else {
      path
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _ChannelMessageMenuPointerPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.pointsDown != pointsDown;
  }
}

class _ConversationWriteBar extends StatelessWidget {
  const _ConversationWriteBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            context.tk.bg.withValues(alpha: 0),
            context.tk.bg.withValues(alpha: 0.96),
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const _WriteCircleButton(icon: Symbols.keyboard_alt),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 40,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: context.tk.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _channelShadowColor(context),
                    blurRadius: 37,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Text(
                '按住 说话',
                style: AppTheme.sans(
                  size: 15,
                  weight: FontWeight.w600,
                  color: context.tk.text,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const _WriteCircleButton(icon: Symbols.mood),
          const SizedBox(width: 8),
          const _WriteCircleButton(icon: Symbols.add),
        ],
      ),
    );
  }
}

class _WriteCircleButton extends StatelessWidget {
  const _WriteCircleButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: context.tk.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _channelShadowColor(context),
            blurRadius: 37,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Icon(icon, size: 24, color: context.tk.text),
    );
  }
}

Color _channelShadowColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? Colors.black.withValues(alpha: 0.34)
      : Colors.black.withValues(alpha: 0.12);
}
