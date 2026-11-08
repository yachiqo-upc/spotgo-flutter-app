import 'package:flutter/material.dart';

/// SpotGo palette taken from the Parking Admin mockups (dark theme, yellow accent).
abstract final class AppColors {
  static const Color background = Color(0xFF0E0D13);
  static const Color surface = Color(0xFF17161E);
  static const Color surfaceAlt = Color(0xFF201F29);
  static const Color border = Color(0xFF34333D);
  static const Color navBar = Color(0xFF15141B);

  static const Color primary = Color(0xFFFFD84D);
  static const Color onPrimary = Color(0xFF15141B);
  static const Color primaryMuted = Color(0xFF3B3421);

  static const Color textPrimary = Color(0xFFF5F5F7);
  static const Color textSecondary = Color(0xFFA3A2AC);
  static const Color textMuted = Color(0xFF75747E);

  static const Color success = Color(0xFF4ADE80);
  static const Color successMuted = Color(0xFF173A26);
  static const Color warning = Color(0xFFFFB547);
  static const Color warningMuted = Color(0xFF3D2F17);
  static const Color danger = Color(0xFFF2726F);
  static const Color dangerMuted = Color(0xFF3F1F22);
  static const Color info = Color(0xFFFFD84D);
  static const Color infoMuted = Color(0xFF2A2A2F);

  static const Color spotOccupied = Color(0xFF2B3446);
  static const Color spotReserved = Color(0xFFFFB547);
  static const Color spotAvailable = Color(0xFF4ADE80);
  static const Color spotUnavailable = Color(0xFF2A1F25);
}
