import 'package:flutter/material.dart';

class AppColors {
  static const navy = Color(0xFF063A63); // deep blue/navy
  static const primaryBlue = Color(0xFF0B67B2); // app bar blue
  static const nuhrisYellow = Color(0xFFFFD000);

  static const pageBg = Color(0xFFE9EEF3);
  static const cardBg = Colors.white;

  static const green = Color(0xFF2EAD4A);
  static const amber = Color(0xFFFFB300);
  static const red = Color(0xFFE53935);

  static const purple = Color(0xFF8E5CE6);
  static const orange = Color(0xFFF59E0B);

  static const mutedText = Color(0xFF6B7280);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: AppColors.primaryBlue,
    brightness: Brightness.light,
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.pageBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primaryBlue,
      foregroundColor: Colors.white,
      centerTitle: false,
      elevation: 2,
    ),
    cardTheme: CardThemeData(
      color: AppColors.cardBg,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}