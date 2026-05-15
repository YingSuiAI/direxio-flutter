import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';

/// 方角头像（4px 圆角），不要圆形——更"设备/protocol"质感。
class PortalAvatar extends StatelessWidget {
  const PortalAvatar({
    super.key,
    required this.seed,
    this.size = 40,
    this.imageUrl,
  });

  final String seed;
  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final hash = seed.codeUnits.fold<int>(0, (a, b) => a + b);
    final palette = [
      t.accent,
      t.accentCool,
      const Color(0xFFA855F7), // purple
      const Color(0xFFF59E0B), // amber
      const Color(0xFFEC4899), // pink
    ];
    final color = palette[hash % palette.length];
    final letter = seed.isNotEmpty ? seed.characters.first.toUpperCase() : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(size * 0.18),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: AppTheme.mono(
          size: size * 0.42,
          color: color,
          weight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// MXID 文本：小号 mono，dim 色，可选中复制。
class PortalMxid extends StatelessWidget {
  const PortalMxid(this.mxid, {super.key, this.size = 12});
  final String mxid;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      mxid,
      style: AppTheme.mono(size: size, color: context.tk.textMute),
    );
  }
}
