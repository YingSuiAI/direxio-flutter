import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'design_tokens.dart';

/// Material 3 主题（对齐 Agent P2P 设计稿）。
/// 字体统一 Noto Sans SC（思源黑体）——中英文全覆盖，各端渲染一致。
class AppTheme {
  static ThemeData light = _buildTheme(PortalTokens.light, Brightness.light);
  static ThemeData dark = _buildTheme(PortalTokens.dark, Brightness.dark);

  static TextStyle _font({
    double? fontSize,
    Color? color,
    FontWeight? fontWeight,
    double letterSpacing = 0,
  }) {
    if (!GoogleFonts.config.allowRuntimeFetching) {
      return TextStyle(
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight ?? FontWeight.w400,
        letterSpacing: letterSpacing,
        fontFamilyFallback: const ['NotoSansSC'],
      );
    }
    return GoogleFonts.notoSansSc(
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight ?? FontWeight.w400,
      letterSpacing: letterSpacing,
    );
  }

  static ThemeData _buildTheme(PortalTokens t, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: t.accent,
      brightness: brightness,
      surface: t.surface,
      onSurface: t.text,
      primary: t.accent,
      secondary: t.accentCool,
      error: t.danger,
    );

    final base = brightness == Brightness.dark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: t.bg,
      dividerColor: t.border,
      extensions: [t],
      textTheme: (GoogleFonts.config.allowRuntimeFetching
              ? GoogleFonts.notoSansScTextTheme(base.textTheme)
              : base.textTheme)
          .apply(bodyColor: t.text, displayColor: t.text),
      appBarTheme: AppBarTheme(
        backgroundColor: t.bg,
        foregroundColor: t.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: _font(
          color: t.text,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: _font(color: t.textMute, fontSize: 15),
        labelStyle: _font(color: t.textMute, fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.accent, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: _font(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.accent,
          textStyle: _font(fontSize: 15),
        ),
      ),
      cardTheme: CardThemeData(
        color: t.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: t.border.withValues(alpha: 0.3)),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.surface,
        indicatorColor: t.accent.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.all(
          _font(fontSize: 11, color: t.text),
        ),
        elevation: 0,
        height: 64,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.accent,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      listTileTheme: ListTileThemeData(
        tileColor: t.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        titleTextStyle: _font(
          color: t.text,
          fontSize: 17,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
        subtitleTextStyle: _font(color: t.textMute, fontSize: 13),
      ),
    );
  }

  /// M3 字阶速记。原 mono/sans 两个生成器都映射到 Inter——
  /// 设计稿无等宽场景，保留双方法仅为兼容现有调用点。
  static TextStyle mono({double size = 13, Color? color, FontWeight? weight}) =>
      _font(
        fontSize: size,
        color: color,
        fontWeight: weight ?? FontWeight.w400,
        letterSpacing: 0,
      );

  static TextStyle sans({double size = 14, Color? color, FontWeight? weight}) =>
      _font(
        fontSize: size,
        color: color,
        fontWeight: weight ?? FontWeight.w400,
        letterSpacing: 0,
      );
}
