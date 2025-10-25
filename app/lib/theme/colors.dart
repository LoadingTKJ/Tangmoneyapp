import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color indigoBase = Color(0xFF6366F1);
  static const Color violetBase = Color(0xFF8B5CF6);
  static const Color blueBase = Color(0xFF3B82F6);
  static const Color surfaceLight = Color(0xFFF6F6FF);
  static const Color surfaceDark = Color(0xFF111027);

  static LinearGradient get primaryGradient => const LinearGradient(
        colors: [indigoBase, violetBase, blueBase],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}
