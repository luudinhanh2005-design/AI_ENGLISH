/// Design dimensions: spacing, border radius, and sizing constants.
class AppDimensions {
  AppDimensions._();

  // ---------------------------------------------// Spacing
  // ---------------------------------------------
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;

  // ---------------------------------------------// Border Radius
  // ---------------------------------------------
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusXxl = 28.0;
  static const double radiusFull = 100.0;

  // ---------------------------------------------// Component Sizing
  // ---------------------------------------------
  static const double buttonHeight = 56.0;
  static const double buttonHeightSmall = 44.0;
  static const double inputHeight = 56.0;
  static const double appBarHeight = 56.0;
  static const double bottomNavHeight = 80.0;
  static const double iconSize = 24.0;
  static const double iconSizeLg = 32.0;
  static const double avatarSize = 48.0;
  static const double avatarSizeLg = 80.0;

  // ---------------------------------------------// Card
  // ---------------------------------------------
  static const double cardElevation = 0.0;
  static const double cardPadding = 16.0;

  // ---------------------------------------------// Screen Padding
  // ---------------------------------------------
  static const double screenPaddingH = 20.0;
  static const double screenPaddingV = 16.0;

  // ---------------------------------------------// Animation Duration
  // ---------------------------------------------
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animNormal = Duration(milliseconds: 350);
  static const Duration animSlow = Duration(milliseconds: 500);
}
