import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RacingTheme {
  // Brand Palette
  static Color background = const Color(0xFF0A0C10);
  static Color panel = const Color(0xFF0D1014);
  static Color border = const Color(0xFF3A4556); // Made more visible
  
  static Color primaryAccent = const Color(0xFF7DD3FC);
  static Color primaryAccentText = Colors.black;
  static Color warning = const Color(0xFFF59E0B);
  static Color danger = const Color(0xFFEF4444);
  static Color success = const Color(0xFF10B981);
  
  static Color textPrimary = const Color(0xFFF1F5F9);
  static Color textSecondary = const Color(0xFFCBD5E1);
  static Color textMuted = const Color(0xFF94A3B8);
  static Color gridLine = const Color(0xFF1E2530);
  static Color chatBubble = const Color(0xFF1E2530);

  static void setLightMode(bool isLight) {
    if (isLight) {
      background = const Color(0xFFF8FAFC);
      panel = const Color(0xFFFFFFFF);
      border = const Color(0xFFCBD5E1); // Made more visible in light mode too
      primaryAccent = const Color(0xFF0284C7);
      primaryAccentText = Colors.white;
      textPrimary = const Color(0xFF0F172A);
      textSecondary = const Color(0xFF475569);
      textMuted = const Color(0xFF94A3B8);
      gridLine = const Color(0xFFE2E8F0);
      chatBubble = const Color(0xFFF1F5F9);
    } else {
      background = const Color(0xFF0A0C10);
      panel = const Color(0xFF0D1014);
      border = const Color(0xFF3A4556);
      primaryAccent = const Color(0xFF7DD3FC);
      primaryAccentText = Colors.black;
      textPrimary = const Color(0xFFF1F5F9);
      textSecondary = const Color(0xFFCBD5E1);
      textMuted = const Color(0xFF94A3B8);
      gridLine = const Color(0xFF1E2530);
      chatBubble = const Color(0xFF1E2530);
    }
  }

  static ThemeData getTheme() {
    final baseTheme = ThemeData.dark();
    
    final labelFont = GoogleFonts.inter(color: textPrimary);
    final dataFont = GoogleFonts.jetBrainsMono(color: textPrimary);

    return ThemeData(
      brightness: background == const Color(0xFFF8FAFC) ? Brightness.light : Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primaryAccent,
      colorScheme: ColorScheme(
        brightness: background == const Color(0xFFF8FAFC) ? Brightness.light : Brightness.dark,
        primary: primaryAccent,
        onPrimary: Colors.white,
        secondary: primaryAccent,
        onSecondary: Colors.white,
        error: danger,
        onError: Colors.white,
        surface: panel,
        onSurface: textPrimary,
      ),
      textTheme: baseTheme.textTheme.copyWith(
        displayLarge: dataFont.copyWith(fontWeight: FontWeight.bold, fontSize: 32),
        displayMedium: dataFont.copyWith(fontWeight: FontWeight.bold, fontSize: 24),
        displaySmall: dataFont.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
        bodyLarge: labelFont.copyWith(fontSize: 16),
        bodyMedium: labelFont.copyWith(fontSize: 14),
        bodySmall: labelFont.copyWith(fontSize: 13, color: textSecondary),
        labelLarge: labelFont.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
        labelSmall: labelFont.copyWith(fontWeight: FontWeight.w500, fontSize: 13, color: textMuted),
      ),
      dividerTheme: DividerThemeData(
        color: border,
        space: 1,
        thickness: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: panel,
        elevation: 0,
        centerTitle: false,
        shape: Border(bottom: BorderSide(color: border, width: 1)),
        titleTextStyle: labelFont.copyWith(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(border),
        trackColor: WidgetStateProperty.all(Colors.transparent),
        thickness: WidgetStateProperty.all(6.0),
        radius: const Radius.circular(3.0),
      ),
      cardTheme: CardThemeData(
        color: panel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: border, width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryAccent,
          foregroundColor: background,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          textStyle: labelFont.copyWith(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textSecondary,
        ),
      ),
    );
  }
  
  static TextStyle get chartTextStyle => GoogleFonts.jetBrainsMono(
    color: textPrimary,
    fontSize: 12,
  );
  
  static TextStyle get chartTitleStyle => GoogleFonts.inter(
    color: textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.bold,
  );
}
