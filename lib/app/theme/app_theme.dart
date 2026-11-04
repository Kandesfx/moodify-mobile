import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppColors {
  static const background = Color(0xFF08090D);
  static const surface = Color(0xFF121319);
  static const surfaceRaised = Color(0xFF1B1C25);
  static const border = Color(0xFF2B2D39);
  static const text = Color(0xFFF4F2ED);
  static const secondary = Color(0xFFB7B5C0);
  static const primary = Color(0xFF7A5CFF);
  static const error = Color(0xFFFF8796);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.dark,
    primary: AppColors.primary,
    onPrimary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    error: AppColors.error,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'BeVietnamPro',
    scaffoldBackgroundColor: AppColors.background,
    visualDensity: VisualDensity.standard,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 28,
        height: 1.3,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.7,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        height: 1.4,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        height: 1.4,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5),
      labelLarge: TextStyle(
        fontSize: 15,
        height: 1.4,
        fontWeight: FontWeight.w600,
      ),
    ).apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    appBarTheme: const AppBarThemeData(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      hintStyle: const TextStyle(color: AppColors.secondary, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      errorMaxLines: 3,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 56),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFFB7A7FF),
        minimumSize: const Size(48, 48),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
  );
}
