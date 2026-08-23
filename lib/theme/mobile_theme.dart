import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MobileTheme {
  // Deep, rich background colors for OLEDs
  static const Color backgroundStart = Color(0xFF090B10);
  static const Color backgroundEnd = Color(0xFF141926);

  // Vibrant UI Accents
  static const Color primaryNeon = Color(0xFF00F0FF); // Cyan Glow
  static const Color secondaryNeon = Color(0xFFFF007F); // Magenta Glow
  static const Color successGlow = Color(0xFF00FF88);
  static const Color dangerGlow = Color(0xFFFF3333);

  // Text Colors
  static const Color textBright = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFFA0ABC0);

  // Glassmorphism Utilities
  static BoxDecoration glassDecoration({double radius = 24.0, bool isActive = false}) {
    return BoxDecoration(
      color: Colors.white.withOpacity(isActive ? 0.1 : 0.03),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: Colors.white.withOpacity(isActive ? 0.2 : 0.05),
        width: 1.5,
      ),
      boxShadow: isActive
          ? [
              BoxShadow(
                color: primaryNeon.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 1,
              )
            ]
          : [],
    );
  }

  static ThemeData getTheme() {
    final baseTheme = ThemeData.dark();

    // Modern, rounded font for a premium feel
    final headingFont = GoogleFonts.outfit(color: textBright);
    final dataFont = GoogleFonts.firaCode(color: textBright);

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundStart,
      primaryColor: primaryNeon,
      colorScheme: const ColorScheme.dark(
        primary: primaryNeon,
        secondary: secondaryNeon,
        error: dangerGlow,
        surface: Color(0xFF111520),
      ),
      textTheme: baseTheme.textTheme.copyWith(
        displayLarge: dataFont.copyWith(fontWeight: FontWeight.w900, fontSize: 36),
        displayMedium: dataFont.copyWith(fontWeight: FontWeight.bold, fontSize: 28),
        displaySmall: headingFont.copyWith(fontWeight: FontWeight.bold, fontSize: 20),
        bodyLarge: headingFont.copyWith(fontSize: 16),
        bodyMedium: headingFont.copyWith(fontSize: 14),
        bodySmall: headingFont.copyWith(fontSize: 13, color: textMuted),
        labelLarge: headingFont.copyWith(fontWeight: FontWeight.w600, fontSize: 14),
        labelSmall: headingFont.copyWith(fontWeight: FontWeight.w500, fontSize: 12, color: textMuted),
      ),
    );
  }
}
