import 'package:flutter/material.dart';

/// Design tokens for Portal IM.
/// "Terminal-grade serenity" — developer-friendly dark-first with proper light theme.
class PortalTokens extends ThemeExtension<PortalTokens> {
  const PortalTokens({
    required this.bg,
    required this.surface,
    required this.surfaceHover,
    required this.border,
    required this.text,
    required this.textMute,
    required this.accent,
    required this.accentCool,
    required this.danger,
  });

  final Color bg;
  final Color surface;
  final Color surfaceHover;
  final Color border;
  final Color text;
  final Color textMute;
  final Color accent;
  final Color accentCool;
  final Color danger;

  static const dark = PortalTokens(
    bg: Color(0xFF0F172A),
    surface: Color(0xFF1E293B),
    surfaceHover: Color(0xFF334155),
    border: Color(0xFF334155),
    text: Color(0xFFF8FAFC),
    textMute: Color(0xFF94A3B8),
    accent: Color(0xFF22C55E),
    accentCool: Color(0xFF38BDF8),
    danger: Color(0xFFEF4444),
  );

  static const light = PortalTokens(
    bg: Color(0xFFFAFAF9),
    surface: Color(0xFFFFFFFF),
    surfaceHover: Color(0xFFF4F4F5),
    border: Color(0xFFE4E4E7),
    text: Color(0xFF0F172A),
    textMute: Color(0xFF52525B),
    accent: Color(0xFF16A34A),
    accentCool: Color(0xFF0284C7),
    danger: Color(0xFFDC2626),
  );

  @override
  PortalTokens copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceHover,
    Color? border,
    Color? text,
    Color? textMute,
    Color? accent,
    Color? accentCool,
    Color? danger,
  }) =>
      PortalTokens(
        bg: bg ?? this.bg,
        surface: surface ?? this.surface,
        surfaceHover: surfaceHover ?? this.surfaceHover,
        border: border ?? this.border,
        text: text ?? this.text,
        textMute: textMute ?? this.textMute,
        accent: accent ?? this.accent,
        accentCool: accentCool ?? this.accentCool,
        danger: danger ?? this.danger,
      );

  @override
  PortalTokens lerp(ThemeExtension<PortalTokens>? other, double t) {
    if (other is! PortalTokens) return this;
    return PortalTokens(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHover: Color.lerp(surfaceHover, other.surfaceHover, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMute: Color.lerp(textMute, other.textMute, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentCool: Color.lerp(accentCool, other.accentCool, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

/// 便捷访问：Theme.of(context).extension<PortalTokens>()!
extension PortalTokensX on BuildContext {
  PortalTokens get tk => Theme.of(this).extension<PortalTokens>()!;
}
