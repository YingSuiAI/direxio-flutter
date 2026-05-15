import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'design_tokens.dart';

class AppTheme {
  static ThemeData light = _buildTheme(PortalTokens.light, Brightness.light);
  static ThemeData dark = _buildTheme(PortalTokens.dark, Brightness.dark);

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
      scaffoldBackgroundColor: t.bg,
      canvasColor: t.bg,
      dividerColor: t.border,
      extensions: [t],

      textTheme: GoogleFonts.ibmPlexSansTextTheme(base.textTheme).apply(
        bodyColor: t.text,
        displayColor: t.text,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: t.bg,
        foregroundColor: t.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.jetBrainsMono(
          color: t.text,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: GoogleFonts.jetBrainsMono(color: t.textMute, fontSize: 14),
        labelStyle: GoogleFonts.ibmPlexSans(color: t.textMute, fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: t.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: t.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: t.accent, width: 1.5),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: brightness == Brightness.dark
              ? const Color(0xFF052e16)
              : Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.ibmPlexSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.textMute,
          textStyle: GoogleFonts.ibmPlexSans(fontSize: 13),
        ),
      ),

      cardTheme: CardThemeData(
        color: t.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: t.border),
        ),
        margin: EdgeInsets.zero,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.surface,
        indicatorColor: t.accent.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.ibmPlexSans(fontSize: 12, color: t.text),
        ),
        elevation: 0,
        height: 64,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.accent,
        foregroundColor: brightness == Brightness.dark
            ? const Color(0xFF052e16)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),

      listTileTheme: ListTileThemeData(
        tileColor: t.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        titleTextStyle: GoogleFonts.ibmPlexSans(
          color: t.text,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: GoogleFonts.jetBrainsMono(
          color: t.textMute,
          fontSize: 12,
        ),
      ),
    );
  }

  /// 快捷：mono 字体 style 生成器
  static TextStyle mono({double size = 13, Color? color, FontWeight? weight}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        color: color,
        fontWeight: weight ?? FontWeight.w400,
        letterSpacing: -0.2,
      );

  static TextStyle sans({double size = 14, Color? color, FontWeight? weight}) =>
      GoogleFonts.ibmPlexSans(
        fontSize: size,
        color: color,
        fontWeight: weight ?? FontWeight.w400,
      );
}
