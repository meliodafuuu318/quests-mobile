import 'package:flutter/material.dart';

class AppTheme {
  static const Color bg = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF12121A);
  static const Color surfaceElevated = Color(0xFF1A1A26);
  static const Color border = Color(0xFF252535);
  static const Color borderBright = Color(0xFF353550);

  static const Color gold = Color(0xFFFFD166);
  static const Color goldDim = Color(0xFF3A2E10);
  static const Color cyan = Color(0xFF06D6A0);
  static const Color cyanDim = Color(0xFF062A20);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color violetDim = Color(0xFF1E1040);
  static const Color rose = Color(0xFFFF4D6D);
  static const Color roseDim = Color(0xFF2A0F18);

  static const Color textPrimary = Color(0xFFF0F0F8);
  static const Color textSecondary = Color(0xFF8888AA);
  static const Color textMuted = Color(0xFF44445A);

  static const TextStyle _base = TextStyle(fontFamily: 'monospace');

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: gold,
        secondary: cyan,
        surface: surface,
        error: rose,
      ),
      textTheme: ThemeData.dark().textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
        fontFamily: 'monospace',
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 16,
          letterSpacing: 2,
          fontFamily: 'monospace',
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: gold, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSecondary, fontFamily: 'monospace'),
        hintStyle: const TextStyle(color: textMuted, fontFamily: 'monospace'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5, fontFamily: 'monospace'),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
    );
  }

  // Text style helpers used across the app
  static TextStyle label({Color color = textPrimary, double size = 14, FontWeight weight = FontWeight.w400}) =>
      TextStyle(color: color, fontSize: size, fontWeight: weight, fontFamily: 'monospace');

  static TextStyle mono({Color color = gold, double size = 13, FontWeight weight = FontWeight.w700}) =>
      TextStyle(color: color, fontSize: size, fontWeight: weight, fontFamily: 'monospace', letterSpacing: 0.5);
}