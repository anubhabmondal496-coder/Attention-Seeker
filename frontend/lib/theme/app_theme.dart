import 'package:flutter/material.dart';

class AppTheme {
  // Standard Restrained Palette
  static const Color background = Color(0xFF0E1116);
  static const Color surface = Color(0xFF161A22);
  static const Color surfaceElevated = Color(0xFF1E232E);
  static const Color border = Color(0xFF2C323F);
  static const Color borderSubtle = Color(0xFF202530);

  // Technical amber / gold accent
  static const Color accent = Color(0xFFE5A93C);
  static const Color accentMuted = Color(0xFF2A2215);

  // Typography
  static const Color textPrimary = Color(0xFFF0F3F7);
  static const Color textSecondary = Color(0xFF9AA3AF);
  static const Color textMuted = Color(0xFF758092);

  // Semantic Status Colors
  static const Color statusIdle = Color(0xFF6B7280);
  static const Color statusSearching = Color(0xFF38BDF8);
  static const Color statusCandidate = Color(0xFFFBBF24);
  static const Color statusFound = Color(0xFF34D399);
  static const Color statusError = Color(0xFFF87171);

  // High Contrast Palette (for Low Vision & Visually Impaired)
  static const Color hcBackground = Color(0xFF000000);
  static const Color hcSurface = Color(0xFF121212);
  static const Color hcSurfaceElevated = Color(0xFF1F1F1F);
  static const Color hcBorder = Color(0xFFFFFFFF);
  static const Color hcAccent = Color(0xFFFFD700); // Pure Vivid Gold
  static const Color hcTextPrimary = Color(0xFFFFFFFF); // Pure White
  static const Color hcTextSecondary = Color(0xFFE0E0E0);
  static const Color hcStatusFound = Color(0xFF00FF66); // Vivid Neon Green
  static const Color hcStatusCandidate = Color(0xFFFFCC00);

  static Color getBackgroundColor(bool highContrast) => highContrast ? hcBackground : background;
  static Color getSurfaceColor(bool highContrast) => highContrast ? hcSurface : surface;
  static Color getBorderColor(bool highContrast) => highContrast ? hcBorder : border;
  static Color getAccentColor(bool highContrast) => highContrast ? hcAccent : accent;
  static Color getTextPrimaryColor(bool highContrast) => highContrast ? hcTextPrimary : textPrimary;
  static Color getTextSecondaryColor(bool highContrast) => highContrast ? hcTextSecondary : textSecondary;

  static ThemeData getThemeData({bool highContrast = false, bool largeFont = false}) {
    final bg = getBackgroundColor(highContrast);
    final surf = getSurfaceColor(highContrast);
    final brd = getBorderColor(highContrast);
    final acc = getAccentColor(highContrast);
    final txt = getTextPrimaryColor(highContrast);
    final fontScale = largeFont ? 1.25 : 1.0;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.dark(
        surface: surf,
        primary: acc,
        onPrimary: Colors.black,
        onSurface: txt,
        outline: brd,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: txt,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18 * fontScale,
          fontWeight: FontWeight.w700,
          color: txt,
          letterSpacing: 0.3,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: acc,
          foregroundColor: Colors.black,
          elevation: highContrast ? 2 : 0,
          minimumSize: Size(double.infinity, 54 * fontScale),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
            side: highContrast ? const BorderSide(color: Colors.white, width: 2) : BorderSide.none,
          ),
          textStyle: TextStyle(
            fontSize: 16 * fontScale,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: txt,
          side: BorderSide(color: brd, width: highContrast ? 2.0 : 1.2),
          minimumSize: Size(double.infinity, 52 * fontScale),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          textStyle: TextStyle(
            fontSize: 15 * fontScale,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surf,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: brd, width: highContrast ? 2.0 : 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: brd, width: highContrast ? 2.0 : 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: acc, width: 2.5),
        ),
        hintStyle: TextStyle(
          color: highContrast ? const Color(0xFFAAAAAA) : textMuted,
          fontSize: 15 * fontScale,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  // Backwards compatibility default
  static ThemeData get themeData => getThemeData();
}
