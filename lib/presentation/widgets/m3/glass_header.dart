// M3 毛玻璃头部 —— 对齐 Agent P2P 设计稿 .glass
//
// 不是 PreferredSizeWidget / 不当 Scaffold.appBar。
// 直接放进 body Column 顶部，内部自取状态栏高度撑高，避免 appBar
// 路径下 SafeArea 与 preferredSize 冲突导致的错位。
//
// 两种形态：
// - [GlassHeader.primary]：消息列表式（左头像/标题 + 右图标按钮组），内容高 56
// - [GlassHeader.detail]：子页式（返回箭头 + 居中标题/副标题 + 右按钮），内容高 60
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/theme/app_theme.dart';

class GlassHeader extends StatelessWidget {
  const GlassHeader._({required this.contentHeight, required this.child});

  /// 消息列表式头部：左侧自定义内容 + 右侧按钮组。
  factory GlassHeader.primary({
    Widget? leading,
    required String title,
    Color? titleColor,
    List<Widget> actions = const [],
  }) {
    return GlassHeader._(
      contentHeight: 56,
      child: _PrimaryContent(
        leading: leading,
        title: title,
        titleColor: titleColor,
        actions: actions,
      ),
    );
  }

  /// 子页式头部：返回箭头 + 居中标题（可带副标题）+ 右侧按钮。
  factory GlassHeader.detail({
    required String title,
    String? subtitle,
    IconData? subtitleIcon,
    VoidCallback? onBack,
    List<Widget> actions = const [],
    Widget? centerLeading,
    Widget? titleTrailing,
  }) {
    return GlassHeader._(
      contentHeight: 60,
      child: _DetailContent(
        title: title,
        subtitle: subtitle,
        subtitleIcon: subtitleIcon,
        onBack: onBack,
        actions: actions,
        centerLeading: centerLeading,
        titleTrailing: titleTrailing,
      ),
    );
  }

  final double contentHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final topInset = MediaQuery.of(context).padding.top;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: contentHeight + topInset,
          padding: EdgeInsets.only(top: topInset),
          decoration: BoxDecoration(
            color: t.surface.withValues(alpha: 0.58),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PrimaryContent extends StatelessWidget {
  const _PrimaryContent({
    required this.leading,
    required this.title,
    this.titleColor,
    required this.actions,
  });
  final Widget? leading;
  final String title;
  final Color? titleColor;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.sans(
                size: 24,
                weight: FontWeight.w600,
                color: titleColor ?? t.text,
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.title,
    this.subtitle,
    this.subtitleIcon,
    this.onBack,
    this.actions = const [],
    this.centerLeading,
    this.titleTrailing,
  });
  final String title;
  final String? subtitle;
  final IconData? subtitleIcon;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Widget? centerLeading;
  final Widget? titleTrailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    const sideWidth = 88.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: sideWidth,
              child: Row(
                children: [
                  GlassHeaderButton(
                    icon: Symbols.arrow_back,
                    color: t.text,
                    onTap: onBack ?? () => Navigator.of(context).maybePop(),
                  ),
                  if (centerLeading != null) ...[
                    centerLeading!,
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: sideWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTheme.sans(
                          size: 20,
                          weight: FontWeight.w600,
                          color: t.text,
                        ),
                      ),
                    ),
                    if (titleTrailing != null) ...[
                      const SizedBox(width: 6),
                      titleTrailing!,
                    ],
                  ],
                ),
                if (subtitle != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (subtitleIcon != null) ...[
                        Icon(subtitleIcon, size: 11, color: t.accentCool),
                        const SizedBox(width: 3),
                      ],
                      Flexible(
                        child: Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppTheme.sans(size: 11, color: t.textMute),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: sideWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 头部图标按钮——圆形，点按缩放反馈。
class GlassHeaderButton extends StatelessWidget {
  const GlassHeaderButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color,
    this.size = 40,
    this.iconSize = 22,
  });
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: t.text.withValues(alpha: 0.12),
            blurRadius: 36,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: t.surface.withValues(alpha: 0.65),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(icon, size: iconSize, color: color ?? t.textMute),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
