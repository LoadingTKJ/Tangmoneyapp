import 'package:flutter/material.dart';

import 'colors.dart';

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.indigoBase,
    brightness: brightness,
  );

  return ThemeData(
    colorScheme: colorScheme,
    brightness: brightness,
    useMaterial3: true,
    fontFamily: 'SF Pro',
    scaffoldBackgroundColor:
        isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: isDark ? Colors.white : Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 20,
      ),
    ),
    cardTheme: CardThemeData(
      color: isDark
          ? const Color(0xFF1E1B4B).withValues(alpha: 0.85)
          : Colors.white.withValues(alpha: 0.75),
      elevation: 4,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        backgroundColor: AppColors.indigoBase,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.indigoBase,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      elevation: 6,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: isDark
          ? const Color(0xFF1C1A3B).withValues(alpha: 0.9)
          : Colors.white.withValues(alpha: 0.85),
      selectedItemColor: AppColors.indigoBase,
      unselectedItemColor: colorScheme.onSurfaceVariant,
      showUnselectedLabels: true,
      elevation: 10,
      type: BottomNavigationBarType.fixed,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.indigoBase,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
