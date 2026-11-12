// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const background = Color(0xFFF8F5F0);
  static const primary = Color(0xFF342B1C);
  static const brown = Color(0xFF6B553D);
  static const green = Color(0xFF5CA38C);
  static const grey = Color(0xFF6C7278);
  static const headerBeige = Color(0xFFD9C5B2);
  static const sos = Color(0xFFDD0000);

  static const darkBackground = Color(0xFF1E1B17);
  static const darkSurface = Color(0xFF2A2621);
  static const darkHeader = Color(0xFF3A3128);
}

class AppTheme {
  AppTheme._();

  static const fontFamily = 'Itim';

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.green,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.green,
      tertiary: AppColors.brown,
      onTertiary: Colors.white,
      surface: Colors.white,
      onSurface: const Color(0xFF1F1B16),
      onSurfaceVariant: AppColors.grey,
      primaryContainer: AppColors.headerBeige,
      surfaceContainerHighest: const Color(0xFFEFEFF3),
      error: AppColors.sos,
    );
    return _build(scheme, AppColors.background);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.green,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFFE9DCC6),
      onPrimary: AppColors.primary,
      secondary: AppColors.green,
      tertiary: const Color(0xFFD9C3A5),
      onTertiary: AppColors.primary,
      surface: AppColors.darkSurface,
      onSurface: const Color(0xFFF2ECE4),
      onSurfaceVariant: const Color(0xFFB8B0A6),
      primaryContainer: AppColors.darkHeader,
      surfaceContainerHighest: const Color(0xFF3A352E),
      error: const Color(0xFFFF5A5A),
    );
    return _build(scheme, AppColors.darkBackground);
  }

  static ThemeData _build(ColorScheme scheme, Color background) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: background,
    );

    final textTheme = base.textTheme
        .copyWith(
          headlineMedium: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
          titleLarge: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          titleMedium: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          bodyLarge: const TextStyle(fontSize: 20),
          bodyMedium: const TextStyle(fontSize: 18),
          labelLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        )
        .apply(
          fontFamily: fontFamily,
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.titleLarge,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(56),
          elevation: 0,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.tertiary,
          textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 18),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        hintStyle: TextStyle(fontSize: 18, color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.green, width: 2),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}