import 'package:flutter/material.dart';

/// Design tokens for Portal IM.
/// Material 3 配色体系（对齐 Agent P2P 设计稿）。
/// 前 9 个字段为历史稳定字段；后续 M3 扩展字段供新组件精细使用。
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
    required this.onAccent,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.surfaceHigh,
    required this.secondaryContainer,
    required this.tertiaryFixed,
  });

  // —— 历史稳定字段 ——
  final Color bg; // background
  final Color surface; // surface-container-lowest
  final Color surfaceHover; // surface-container
  final Color border; // outline-variant
  final Color text; // on-background
  final Color textMute; // on-surface-variant
  final Color accent; // primary
  final Color accentCool; // tertiary
  final Color danger; // error

  // —— M3 扩展字段 ——
  final Color onAccent; // on-primary（accent 上的文字色）
  final Color primaryContainer; // primary-container
  final Color onPrimaryContainer; // on-primary-container
  final Color surfaceHigh; // surface-container-high（对方气泡背景等）
  final Color secondaryContainer; // secondary-container（nav pill 等）
  final Color tertiaryFixed; // tertiary-fixed（在线状态绿点）

  // M3 浅色（来自设计稿 tailwind.config）
  static const light = PortalTokens(
    bg: Color(0xFFF9F9FE),
    surface: Color(0xFFFFFFFF),
    surfaceHover: Color(0xFFEDEDF2),
    border: Color(0xFFC1C6D7),
    text: Color(0xFF1A1C1F),
    textMute: Color(0xFF414755),
    accent: Color(0xFF3097CB),
    accentCool: Color(0xFF006B27),
    danger: Color(0xFFBA1A1A),
    onAccent: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF0070EB),
    onPrimaryContainer: Color(0xFFFEFCFF),
    surfaceHigh: Color(0xFFE8E8ED),
    secondaryContainer: Color(0xFFE0DFE4),
    tertiaryFixed: Color(0xFF72FE88),
  );

  // M3 深色（设计稿仅给浅色，按 M3 标准深色调色板补全）
  static const dark = PortalTokens(
    bg: Color(0xFF111318),
    surface: Color(0xFF1E2026),
    surfaceHover: Color(0xFF2A2D33),
    border: Color(0xFF42474E),
    text: Color(0xFFE2E2E9),
    textMute: Color(0xFFC3C6CF),
    accent: Color(0xFFADC6FF),
    accentCool: Color(0xFF53E16F),
    danger: Color(0xFFFFB4AB),
    onAccent: Color(0xFF002E69),
    primaryContainer: Color(0xFF004493),
    onPrimaryContainer: Color(0xFFD8E2FF),
    surfaceHigh: Color(0xFF292B31),
    secondaryContainer: Color(0xFF3F4759),
    tertiaryFixed: Color(0xFF72FE88),
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
    Color? onAccent,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? surfaceHigh,
    Color? secondaryContainer,
    Color? tertiaryFixed,
  }) => PortalTokens(
    bg: bg ?? this.bg,
    surface: surface ?? this.surface,
    surfaceHover: surfaceHover ?? this.surfaceHover,
    border: border ?? this.border,
    text: text ?? this.text,
    textMute: textMute ?? this.textMute,
    accent: accent ?? this.accent,
    accentCool: accentCool ?? this.accentCool,
    danger: danger ?? this.danger,
    onAccent: onAccent ?? this.onAccent,
    primaryContainer: primaryContainer ?? this.primaryContainer,
    onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
    surfaceHigh: surfaceHigh ?? this.surfaceHigh,
    secondaryContainer: secondaryContainer ?? this.secondaryContainer,
    tertiaryFixed: tertiaryFixed ?? this.tertiaryFixed,
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
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      primaryContainer: Color.lerp(
        primaryContainer,
        other.primaryContainer,
        t,
      )!,
      onPrimaryContainer: Color.lerp(
        onPrimaryContainer,
        other.onPrimaryContainer,
        t,
      )!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      secondaryContainer: Color.lerp(
        secondaryContainer,
        other.secondaryContainer,
        t,
      )!,
      tertiaryFixed: Color.lerp(tertiaryFixed, other.tertiaryFixed, t)!,
    );
  }
}

/// 便捷访问：Theme.of(context).extension<PortalTokens>()!
extension PortalTokensX on BuildContext {
  PortalTokens get tk => Theme.of(this).extension<PortalTokens>()!;
}
