import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand palette — matches meal-admin (`--accent-primary: #ff4d00`)
  static const Color primaryColor = Color(0xFFFF4D00);
  static const Color primaryDark = Color(0xFFE64500);
  static const Color accentColor = Color(0xFFF43F5E); // Rose 500
  
  // Light Theme Colors
  static const Color backgroundLight = Color(0xFFF6F0E6); // warm paper
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF0F172A); // Slate 900
  static const Color textSecondaryLight = Color(0xFF475569); // Slate 600
  static const Color borderLight = Color(0xFFE2E8F0); // Slate 200
  static const Color borderDark = Color(0xFF334155); // Slate 700 — PURE WHITE text for readability
  static const Color backgroundDark = Color(0xFF121214); // deep charcoal
  static const Color surfaceDark = Color(0xFF1C1C1E); // elevated dark surface
  static const Color textPrimaryDark = Color(0xFFF3F4F6); // crisp off-white
  static const Color textSecondaryDark = Color(0xFFCBD5E1); // Slate 300 — brighter secondary
  // Segmented plan picker (meal size tabs)
  static const Color segmentedTrackLight = Color(0xFFE8EEF4);
  static const Color segmentedTrackDark = Color(0xFF1E293B);
  static const Color segmentedBorderLight = Color(0xFFCBD5E1);
  static const Color segmentedBorderDark = Color(0xFF334155);

  /// Status bar + Android navigation bar colors matching the screen background.
  /// Warm off-white/beige for light-mode screens.
  static const Color pageBackgroundLight = Color(0xFFFAF8F5);

  static SystemUiOverlayStyle overlayFor({
    required Color background,
    required bool isDark,
    Color? navigationBarColor,
  }) {
    final navColor = navigationBarColor ?? (isDark ? AppTheme.surfaceDark : background);
    return SystemUiOverlayStyle(
      statusBarColor: background,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: navColor,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: navColor,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    );
  }

  static ThemeData get lightTheme => _createTheme(
    brightness: Brightness.light,
    background: pageBackgroundLight,
    surface: surfaceLight,
    textPrimary: textPrimaryLight,
    textSecondary: textSecondaryLight,
    border: borderLight,
  );

  static ThemeData get darkTheme => _createTheme(
    brightness: Brightness.dark,
    background: backgroundDark,
    surface: surfaceDark,
    textPrimary: textPrimaryDark,
    textSecondary: textSecondaryDark,
    border: borderDark,
  );

  static ThemeData _createTheme({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color textPrimary,
    required Color textSecondary,
    required Color border,
  }) {
    final isDark = brightness == Brightness.dark;
    final baseTextTheme = GoogleFonts.poppinsTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );
    
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: brightness,
        primary: primaryColor,
        secondary: accentColor,
        surface: surface,
      ),
      cardColor: surface,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: textPrimary),
        systemOverlayStyle: overlayFor(background: background, isDark: isDark),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.w900),
        displayMedium: baseTextTheme.displayMedium?.copyWith(color: textPrimary, fontWeight: FontWeight.w800),
        titleLarge: baseTextTheme.titleLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.w700),
        titleMedium: baseTextTheme.titleMedium?.copyWith(color: textPrimary, fontWeight: FontWeight.w600),
        titleSmall: baseTextTheme.titleSmall?.copyWith(color: textPrimary, fontWeight: FontWeight.w600),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.w500),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: textSecondary, fontWeight: FontWeight.w500),
        bodySmall: baseTextTheme.bodySmall?.copyWith(color: textSecondary, fontWeight: FontWeight.w500),
        labelLarge: baseTextTheme.labelLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.w600),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? border.withValues(alpha: 0.3) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: isDark ? border.withValues(alpha: 0.5) : border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: isDark ? border.withValues(alpha: 0.5) : border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: primaryColor, width: 2.5),
        ),
        labelStyle: TextStyle(color: textSecondary),
        prefixIconColor: textSecondary,
      ),
    );
  }
}
