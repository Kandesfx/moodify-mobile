import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppColors {
  // Taste-skill: Deep studio dark mode (Obsidian / Onyx neutrals, no purple hue)
  static const background = Color(0xFF090A0D);
  static const surface = Color(0xFF111318);
  static const surfaceRaised = Color(0xFF171A21);
  static const surfaceGlass = Color(0xFF1E222B);
  static const border = Color(0x1FFFFFFF);
  static const borderSoft = Color(0x12FFFFFF);
  static const text = Color(0xFFFAFAFC);
  static const secondary = Color(0xFF8E929E);
  static const primary = Color(0xFF8B5CF6);
  static const primaryDeep = Color(0xFF6D28D9);
  static const lavender = Color(0xFFC4B5FD);
  static const liked = Color(0xFFEC4899);
  static const error = Color(0xFFFF6370);

  // Đặc quyền VIP (chủ đề Hoàng Kim) — chỉ áp dụng khi isPremium
  static const vipGold = Color(0xFFD4AF37);
  static const vipGoldSoft = Color(0xFFF0D98C);
  static const vipBorder = Color(0xFF6B5A2A);
  static const vipGradientTop = Color(0xFF3A2E1A);
  static const vipGradientBottom = Color(0xFF1A1710);
}

abstract final class AppRadii {
  static const double xs = 10;
  static const double sm = 14;
  static const double md = 18;
  static const double lg = 22;
  static const double xl = 26;
  static const double pill = 999;
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
    splashFactory: InkRipple.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 26,
        height: 1.28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
      titleLarge: TextStyle(
        fontSize: 19,
        height: 1.35,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.35,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      bodyLarge: TextStyle(fontSize: 15, height: 1.48),
      bodyMedium: TextStyle(fontSize: 14, height: 1.45),
      labelLarge: TextStyle(
        fontSize: 14,
        height: 1.35,
        fontWeight: FontWeight.w600,
      ),
    ).apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    appBarTheme: const AppBarThemeData(
      titleTextStyle: TextStyle(
        fontFamily: 'BeVietnamPro',
        fontSize: 21,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: AppColors.text,
      ),
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        side: const BorderSide(color: AppColors.borderSoft),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: const BorderSide(color: AppColors.borderSoft),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceGlass,
      contentTextStyle: const TextStyle(
        fontFamily: 'BeVietnamPro',
        fontSize: 13,
        color: AppColors.text,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: AppColors.surfaceRaised,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      hintStyle: const TextStyle(color: AppColors.secondary, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        borderSide: const BorderSide(color: AppColors.borderSoft),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        borderSide: const BorderSide(color: AppColors.borderSoft),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        borderSide: const BorderSide(color: AppColors.text, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      errorMaxLines: 3,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.text,
        minimumSize: const Size(48, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xs),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.borderSoft,
      thickness: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF0C0D11),
      indicatorColor: const Color(0xFF222631),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'BeVietnamPro',
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? AppColors.text
              : AppColors.secondary,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 22,
          color: states.contains(WidgetState.selected)
              ? Colors.white
              : AppColors.secondary,
        ),
      ),
      overlayColor: WidgetStatePropertyAll(Colors.white.withValues(alpha: .06)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: AppColors.secondary.withValues(alpha: 0.35),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: AppColors.borderSoft),
      ),
    ),
  );
}
