import 'package:flutter/material.dart';

/// EnglishAI color palette — modern, educational, premium feel.
/// Uses a primary blue-indigo palette with accent teal and warm highlights.
class AppColors {
  AppColors._();

  // ---------------------------------------------// Brand Colors
  // ---------------------------------------------
  static const Color primary = Color(0xFF6C5CE7);
  static const Color primaryLight = Color(0xFF9B8FEF);
  static const Color primaryDark = Color(0xFF4A3DB8);

  static const Color secondary = Color(0xFF00CEC9);
  static const Color secondaryLight = Color(0xFF55EFC4);
  static const Color secondaryDark = Color(0xFF009E9A);

  static const Color accent = Color(0xFFFF6B6B);
  static const Color accentLight = Color(0xFFFF8E8E);
  static const Color accentDark = Color(0xFFEE4444);

  // ---------------------------------------------// Skill Colors — Each skill gets a distinct color
  // ---------------------------------------------
  static const Color vocabulary = Color(0xFFFF6B6B);
  static const Color grammar = Color(0xFF6C5CE7);
  static const Color listening = Color(0xFF00CEC9);
  static const Color speaking = Color(0xFFFFA502);
  static const Color reading = Color(0xFF2ED573);
  static const Color writing = Color(0xFF3742FA);
  static const Color pronunciation = Color(0xFFFF4757);

  // ---------------------------------------------// Level Colors
  // ---------------------------------------------
  static const Color levelA1 = Color(0xFF2ED573);
  static const Color levelA2 = Color(0xFF7BED9F);
  static const Color levelB1 = Color(0xFFFFA502);
  static const Color levelB2 = Color(0xFFFF6348);
  static const Color levelC1 = Color(0xFFEE4444);
  static const Color levelC2 = Color(0xFF8E44AD);

  // ---------------------------------------------// Dark Theme Colors
  // ---------------------------------------------// Aliases for compatibility
  static const Color backgroundDark = darkBackground;
  static const Color surfaceDark = darkSurface;
  static const Color borderDark = darkDivider;
  static const Color surfaceLightDark = darkCardLight;
  static const Color textPrimaryDark = darkTextPrimary;
  static const Color textSecondaryDark = darkTextSecondary;
  static const Color textHintDark = darkTextHint;
  static const Color darkBackground = Color(0xFF0F0F23);
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color darkCard = Color(0xFF16213E);
  static const Color darkCardLight = Color(0xFF1E2A47);
  static const Color darkDivider = Color(0xFF2A2A4A);
  static const Color darkTextPrimary = Color(0xFFF0F0F5);
  static const Color darkTextSecondary = Color(0xFFB0B0C8);
  static const Color darkTextHint = Color(0xFF6B6B8D);

  // ---------------------------------------------// Light Theme Colors
  // ---------------------------------------------
  static const Color lightBackground = Color(0xFFF8F9FE);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightDivider = Color(0xFFE8E8F0);
  static const Color lightTextPrimary = Color(0xFF1A1A2E);
  static const Color lightTextSecondary = Color(0xFF6B6B8D);
  static const Color lightTextHint = Color(0xFFA0A0B8);

  // ---------------------------------------------// Status Colors
  // ---------------------------------------------
  static const Color success = Color(0xFF2ED573);
  static const Color warning = Color(0xFFFFA502);
  static const Color error = Color(0xFFFF4757);
  static const Color info = Color(0xFF3742FA);

  // ---------------------------------------------// Gradient Presets
  // ---------------------------------------------
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF8E7CF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, secondaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, Color(0xFFFF9A76)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [darkCard, darkCardLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient streakGradient = LinearGradient(
    colors: [Color(0xFFFF6B6B), Color(0xFFFFA502)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient xpGradient = LinearGradient(
    colors: [Color(0xFF6C5CE7), Color(0xFF00CEC9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Theme-aware color palette resolved through the current [ThemeData].
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color background;
  final Color surface;
  final Color card;
  final Color cardLight;
  final Color divider;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;

  const AppPalette({
    required this.background,
    required this.surface,
    required this.card,
    required this.cardLight,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
  });

  static const AppPalette dark = AppPalette(
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    card: AppColors.darkCard,
    cardLight: AppColors.darkCardLight,
    divider: AppColors.darkDivider,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    textHint: AppColors.darkTextHint,
  );

  static const AppPalette light = AppPalette(
    background: AppColors.lightBackground,
    surface: AppColors.lightSurface,
    card: AppColors.lightCard,
    cardLight: AppColors.lightBackground,
    divider: AppColors.lightDivider,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
    textHint: AppColors.lightTextHint,
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? card,
    Color? cardLight,
    Color? divider,
    Color? textPrimary,
    Color? textSecondary,
    Color? textHint,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      cardLight: cardLight ?? this.cardLight,
      divider: divider ?? this.divider,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textHint: textHint ?? this.textHint,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardLight: Color.lerp(cardLight, other.cardLight, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textHint: Color.lerp(textHint, other.textHint, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
