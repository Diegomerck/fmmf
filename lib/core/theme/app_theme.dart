import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Deep sleek dark fintech palette
  static const Color background = Color(0xFF0A0E17);
  static const Color surface = Color(0xFF121824);
  static const Color card = Color(0xFF182234);
  static const Color cardHighlight = Color(0xFF1E2D45);
  static const Color border = Color(0xFF26354D);

  // Accents
  static const Color emeraldGreen = Color(0xFF10B981); // Positive / Income / Yield
  static const Color electricCyan = Color(0xFF06B6D4); // Safe-to-Spend / Advisor
  static const Color alertCoral = Color(0xFFF43F5E);   // Expenses / Warnings
  static const Color amberGold = Color(0xFFF59E0B);    // Attention / Due dates
  static const Color purpleGlow = Color(0xFF8B5CF6);   // Investments / Net worth

  // Text colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: emeraldGreen,
      canvasColor: surface,
      cardColor: card,
      colorScheme: const ColorScheme.dark(
        primary: emeraldGreen,
        secondary: electricCyan,
        surface: surface,
        error: alertCoral,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData.dark().textTheme,
      ).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      dividerColor: border,
    );
  }
}

