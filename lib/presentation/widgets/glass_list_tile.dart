import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import 'app_glass_background.dart';

const glassListTileGap = 5.0;
const glassListTileHorizontalMargin = 6.0;
const glassListTileMargin = EdgeInsets.fromLTRB(
  glassListTileHorizontalMargin,
  0,
  glassListTileHorizontalMargin,
  glassListTileGap,
);
const glassListTileContentPadding = EdgeInsets.fromLTRB(14, 8, 14, 8);
const glassListTileRadius = BorderRadius.all(Radius.circular(28));

class GlassListPanel extends StatelessWidget {
  const GlassListPanel({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.margin = glassListTileMargin,
    this.contentPadding = glassListTileContentPadding,
    this.borderRadius = glassListTileRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry contentPadding;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: AppGlassPanel(
        borderRadius: borderRadius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: contentPadding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class GlassListTile extends StatelessWidget {
  const GlassListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.trailingText,
    this.showChevron = true,
    this.onTap,
    this.onLongPress,
    this.margin = glassListTileMargin,
    this.contentPadding = glassListTileContentPadding,
    this.titleStyle,
    this.subtitleStyle,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final String? trailingText;
  final bool showChevron;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry contentPadding;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final effectiveTitleStyle = titleStyle ??
        AppTheme.sans(
          size: 20,
          weight: FontWeight.w600,
          color: t.text,
        );
    final effectiveSubtitleStyle = subtitleStyle ??
        AppTheme.sans(
          size: 15,
          color: t.textMute,
        );
    return GlassListPanel(
      margin: margin,
      contentPadding: contentPadding,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: effectiveTitleStyle,
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: effectiveSubtitleStyle,
                  ),
                ],
              ],
            ),
          ),
          if (trailingText != null && trailingText!.trim().isNotEmpty) ...[
            const SizedBox(width: 12),
            Text(
              trailingText!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.sans(size: 13, color: t.textMute),
            ),
          ],
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ] else if (showChevron) ...[
            const SizedBox(width: 8),
            Icon(Symbols.chevron_right, size: 22, color: t.textMute),
          ],
        ],
      ),
    );
  }
}

class GlassListIcon extends StatelessWidget {
  const GlassListIcon({
    super.key,
    required this.icon,
    this.size = 48,
    this.iconSize = 24,
    this.fill = 0,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final double fill;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: t.surfaceHigh,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: t.textMute, fill: fill),
    );
  }
}
