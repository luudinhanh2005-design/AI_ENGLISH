import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/test_environment_stub.dart'
    if (dart.library.io) '../utils/test_environment_io.dart';

/// Typography system using Inter font family.
class AppTextStyles {
  AppTextStyles._();

  /// Avoid Google Fonts' network fetch in widget tests. Production still
  /// uses the real Inter family (with its normal runtime fallback behavior).
  static TextStyle _inter({
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
    FontStyle? fontStyle,
  }) {
    if (isFlutterTestEnvironment) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        letterSpacing: letterSpacing,
        fontStyle: fontStyle,
      );
    }
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
      fontStyle: fontStyle,
    );
  }

  // ---------------------------------------------// Headings
  // ---------------------------------------------
  static TextStyle get h1 => _inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.5,
      );

  static TextStyle get h2 => _inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: -0.3,
      );

  static TextStyle get h3 => _inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.3,
      );

  // Title & Headline aliases for Material typography compatibility
  static TextStyle get displayMedium => h1;
  static TextStyle get displaySmall => h2;
  static TextStyle get headlineSmall => h3;
  static TextStyle get titleLarge => h2;
  static TextStyle get titleMedium => h4;
  static TextStyle get titleSmall => _inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
      );
  static TextStyle get h4 => _inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.4,
      );

  // ---------------------------------------------// Body Text
  // ---------------------------------------------
  static TextStyle get bodyLarge => _inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  static TextStyle get bodyMedium => _inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  static TextStyle get bodySmall => _inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  // ---------------------------------------------// Labels / Buttons
  // ---------------------------------------------
  static TextStyle get labelLarge => _inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0.3,
      );

  static TextStyle get labelMedium => _inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.4,
      );

  static TextStyle get labelSmall => _inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
        letterSpacing: 0.3,
      );

  // ---------------------------------------------// Special
  // ---------------------------------------------
  static TextStyle get caption => _inter(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        height: 1.4,
        letterSpacing: 0.4,
      );

  static TextStyle get overline => _inter(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 1.0,
      );

  static TextStyle get phonetic => _inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
      );

  static TextStyle get score => _inter(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        height: 1.0,
      );

  static TextStyle get streakNumber => _inter(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        height: 1.0,
      );
}

