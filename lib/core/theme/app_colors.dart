import 'package:flutter/material.dart';

/// AppColors defines the visual color palette for the Car Parking Management System.
/// Built to match the final approved theme:
/// Primary Navy #0F172A, Secondary Navy #1E3A8A, Primary Orange #F97316, Dark Orange #EA580C.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------------
  // FINAL APPROVED PALETTE
  // ---------------------------------------------------------------------------
  static const Color primaryNavy = Color(0xFF0F172A); // #0F172A
  static const Color secondaryNavy = Color(0xFF1E3A8A); // #1E3A8A
  static const Color primaryOrange = Color(0xFFF97316); // #F97316
  static const Color darkOrange = Color(0xFFEA580C); // #EA580C

  static const Color background = Color(0xFFF8FAFC); // Page Background #F8FAFC
  static const Color surface = Color(0xFFFFFFFF); // Card / Surface #FFFFFF
  static const Color surfaceVariant = Color(0xFFF1F5F9); // Slate 100

  static const Color textPrimary = Color(0xFF0F172A); // Primary Text #0F172A
  static const Color textSecondary = Color(0xFF64748B); // Secondary Text #64748B
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  static const Color border = Color(0xFFE2E8F0); // Border #E2E8F0
  static const Color borderDark = Color(0xFFCBD5E1); // Slate 300

  static const Color success = Color(0xFF10B981); // Success #10B981
  static const Color successDark = Color(0xFF059669);
  static const Color successLight = Color(0xFFECFDF5);

  static const Color warning = Color(0xFFF59E0B); // Warning #F59E0B
  static const Color warningDark = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFFFBEB);

  static const Color error = Color(0xFFDC2626); // Error #DC2626
  static const Color danger = error;
  static const Color dangerDark = Color(0xFFB91C1C);
  static const Color dangerLight = Color(0xFFFEF2F2);

  // ---------------------------------------------------------------------------
  // COMPATIBILITY & SEMANTIC ALIASES
  // ---------------------------------------------------------------------------
  static const Color primary = primaryNavy;
  static const Color primaryDark = Color(0xFF020617);
  static const Color primaryLight = secondaryNavy;
  static const Color primarySurface = Color(0xFFEFF6FF); // Soft blue surface

  static const Color secondary = secondaryNavy;
  static const Color secondaryLight = Color(0xFFEEF2FF);

  static const Color accent = primaryOrange;
  static const Color orange = primaryOrange;
  static const Color orangeDark = darkOrange;
  static const Color orangeLight = Color(0xFFFFF7ED); // Soft orange surface

  static const Color info = secondaryNavy;
  static const Color infoLight = Color(0xFFEFF6FF);

  // Payment colors (Cash = Green #10B981, UPI = Royal Navy #1E3A8A)
  static const Color cashColor = success;
  static const Color cashLight = successLight;
  static const Color upiColor = secondaryNavy;
  static const Color upiLight = Color(0xFFEFF6FF);
}
