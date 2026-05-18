import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';

enum AvatarShape { circle, squircle }

/// 头像 —— M3 风格。
/// 默认圆形（IM 会话/联系人头像）；登录 app icon 等用 squircle（22.5% 圆角）。
class PortalAvatar extends StatelessWidget {
  const PortalAvatar({
    super.key,
    required this.seed,
    this.size = 40,
    this.imageUrl,
    this.shape = AvatarShape.circle,
  });

  final String seed;
  final double size;
  final String? imageUrl;
  final AvatarShape shape;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final hash = seed.codeUnits.fold<int>(0, (a, b) => a + b);
    // M3 容器色系——克制、和谐
    final palette = <(Color bg, Color fg)>[
      (t.primaryContainer, t.onPrimaryContainer),
      (const Color(0xFFE0DFE4), const Color(0xFF1A1B1F)), // secondary-container
      (const Color(0xFFD8E2FF), const Color(0xFF001A41)), // primary-fixed
      (const Color(0xFFC8E6C9), const Color(0xFF002107)), // tertiary tint
    ];
    final (bg, fg) = palette[hash % palette.length];
    final letter = seed.isNotEmpty ? seed.characters.first.toUpperCase() : '?';

    final radius = shape == AvatarShape.circle
        ? BorderRadius.circular(size / 2)
        : BorderRadius.circular(size * 0.225);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: imageUrl != null
          ? Image.network(imageUrl!, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _letter(letter, fg))
          : _letter(letter, fg),
    );
  }

  Widget _letter(String letter, Color fg) => Text(
        letter,
        style: AppTheme.sans(
          size: size * 0.42,
          color: fg,
          weight: FontWeight.w600,
        ),
      );
}

/// 在线状态绿点 —— 叠在头像右下角。
class OnlineDot extends StatelessWidget {
  const OnlineDot({super.key, this.size = 12});
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: t.tertiaryFixed,
        shape: BoxShape.circle,
        border: Border.all(color: t.bg, width: 2),
      ),
    );
  }
}

/// MXID 文本：小号，dim 色，可选中复制。
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
