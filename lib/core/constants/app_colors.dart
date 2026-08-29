import 'package:flutter/material.dart';

/// Centralized color palette for Pukaar Emergency Response System.
/// Designed for high visibility, accessibility, and emergency clarity.
class AppColors {
  AppColors._();

  // Primary Brand Colors
  static const Color primary = Color(0xFFD32F2F); // Emergency Crimson
  static const Color primaryDark = Color(0xFF9A0007);
  static const Color primaryLight = Color(0xFFFF6659);

  // Secondary & Accent Colors
  static const Color secondary = Color(0xFF0D253A); // Deep Navy Slate
  static const Color secondaryLight = Color(0xFF1E3A8A);
  static const Color accent = Color(0xFF0288D1); // Dispatcher / Service Cyan

  // Emergency Specific Categories (Pukaar Core Pillars)
  static const Color medicalEmergency = Color(0xFFE53935); // Medical Red
  static const Color womenSafety = Color(0xFF8E24AA); // Violet / Safety
  static const Color disasterManagement = Color(0xFFEF6C00); // Alert Orange
  static const Color campusEmergency = Color(0xFF00838F); // Campus Teal

  // Semantic Status Colors
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF57C00);
  static const Color error = Color(0xFFC62828);
  static const Color info = Color(0xFF0288D1);

  // Neutral Colors (Light Theme)
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF1A1A1A);
  static const Color textSecondaryLight = Color(0xFF616161);
  static const Color borderLight = Color(0xFFE0E0E0);
  static const Color dividerLight = Color(0xFFEEEEEE);

  // Neutral Colors (Dark Theme)
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color textPrimaryDark = Color(0xFFF5F5F5);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);
  static const Color borderDark = Color(0xFF2C2C2C);
  static const Color dividerDark = Color(0xFF2A2A2A);

  // High-contrast & Overlays
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color overlayDark = Color(0x80000000);
}
