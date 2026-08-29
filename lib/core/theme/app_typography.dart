import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Centralized text styles and typography configuration for Pukaar.
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Roboto';

  // Light Text Styles
  static const TextStyle displayLargeLight = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
    color: AppColors.textPrimaryLight,
    height: 1.2,
  );

  static const TextStyle displayMediumLight = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.25,
    color: AppColors.textPrimaryLight,
    height: 1.25,
  );

  static const TextStyle headlineLargeLight = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimaryLight,
    height: 1.3,
  );

  static const TextStyle headlineMediumLight = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryLight,
    height: 1.35,
  );

  static const TextStyle titleLargeLight = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryLight,
    height: 1.4,
  );

  static const TextStyle bodyLargeLight = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimaryLight,
    height: 1.5,
  );

  static const TextStyle bodyMediumLight = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondaryLight,
    height: 1.45,
  );

  static const TextStyle labelLargeLight = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryLight,
    letterSpacing: 0.1,
  );

  // Dark Text Styles
  static const TextStyle displayLargeDark = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
    color: AppColors.textPrimaryDark,
    height: 1.2,
  );

  static const TextStyle displayMediumDark = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.25,
    color: AppColors.textPrimaryDark,
    height: 1.25,
  );

  static const TextStyle headlineLargeDark = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimaryDark,
    height: 1.3,
  );

  static const TextStyle headlineMediumDark = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryDark,
    height: 1.35,
  );

  static const TextStyle titleLargeDark = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryDark,
    height: 1.4,
  );

  static const TextStyle bodyLargeDark = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimaryDark,
    height: 1.5,
  );

  static const TextStyle bodyMediumDark = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondaryDark,
    height: 1.45,
  );

  static const TextStyle labelLargeDark = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryDark,
    letterSpacing: 0.1,
  );

  // TextTheme Generator
  static TextTheme createTextTheme({required bool isDark}) {
    return TextTheme(
      displayLarge: isDark ? displayLargeDark : displayLargeLight,
      displayMedium: isDark ? displayMediumDark : displayMediumLight,
      headlineLarge: isDark ? headlineLargeDark : headlineLargeLight,
      headlineMedium: isDark ? headlineMediumDark : headlineMediumLight,
      titleLarge: isDark ? titleLargeDark : titleLargeLight,
      bodyLarge: isDark ? bodyLargeDark : bodyLargeLight,
      bodyMedium: isDark ? bodyMediumDark : bodyMediumLight,
      labelLarge: isDark ? labelLargeDark : labelLargeLight,
    );
  }
}
