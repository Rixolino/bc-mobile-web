import 'package:flutter/material.dart';

/// Design tokens for BC Transporter
/// Centralized spacing, radius, typography, and elevation values
class AppTokens {
  // ── SPACING ──
  static const double space2 = 2.0;
  static const double space4 = 4.0;
  static const double space6 = 6.0;
  static const double space8 = 8.0;
  static const double space10 = 10.0;
  static const double space12 = 12.0;
  static const double space14 = 14.0;
  static const double space16 = 16.0;
  static const double space18 = 18.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space28 = 28.0;
  static const double space32 = 32.0;
  static const double space36 = 36.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;
  static const double space56 = 56.0;
  static const double space64 = 64.0;

  // ── BORDER RADIUS ──
  static const double radiusXs = 6.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radius2Xl = 24.0;
  static const double radius3Xl = 28.0;
  static const double radiusFull = 999.0;

  // ── ELEVATION ──
  static const double elevation0 = 0.0;
  static const double elevation1 = 1.0;
  static const double elevation2 = 3.0;
  static const double elevation3 = 6.0;
  static const double elevation4 = 10.0;
  static const double elevation5 = 16.0;

  // ── ICON SIZES ──
  static const double iconXs = 12.0;
  static const double iconSm = 14.0;
  static const double iconMd = 16.0;
  static const double iconLg = 20.0;
  static const double iconXl = 24.0;
  static const double icon2Xl = 28.0;
  static const double icon3Xl = 32.0;
  static const double icon4Xl = 40.0;
  static const double icon5Xl = 48.0;

  // ── TOUCH TARGETS ──
  static const double minTouchTarget = 44.0;
  static const double minButtonHeight = 48.0;
  static const double minButtonHeightSm = 36.0;

  // ── ANIMATION DURATIONS ──
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 250);
  static const Duration animSlow = Duration(milliseconds: 350);
  static const Duration animEmphasis = Duration(milliseconds: 500);

  // ── GLASSMORPHISM ──
  static const double glassBlurLight = 20.0;
  static const double glassBlurDark = 25.0;
  static const double glassOpacityLight = 0.6;
  static const double glassOpacityDark = 0.3;

  // ── BRAND COLORS ──
  static const Color brandOrange = Color(0xFFFF6B35);
  static const Color brandTeal = Color(0xFF43AA8B);
  static const Color brandBlue = Color(0xFF4361EE);
  static const Color brandPurple = Color(0xFF3A0CA3);
  static const Color brandPink = Color(0xFFF72585);
  static const Color brandCyan = Color(0xFF00E5FF);
  static const Color brandIndigo = Color(0xFF7209B7);

  // ── TRANSPORT MODE COLORS ──
  static const Color trainColor = Color(0xFFFF9F1C);
  static const Color busColor = Color(0xFF43AA8B);
  static const Color planeColor = Color(0xFF4361EE);
  static const Color roadColor = Color(0xFF06D6A0);
  static const Color homeColor = Color(0xFF00E5FF);

  // ── SEMANTIC COLORS ──
  static const Color successLight = Color(0xFF2D6A4F);
  static const Color successDark = Color(0xFF52B788);
  static const Color warningLight = Color(0xFFE76F51);
  static const Color warningDark = Color(0xFFFFB703);
  static const Color errorLight = Color(0xFFD00000);
  static const Color errorDark = Color(0xFFFF5400);
  static const Color infoLight = Color(0xFF1976D2);
  static const Color infoDark = Color(0xFF64B5F6);
}

/// Typography scale
class AppTextStyle {
  static const String _primaryFont = 'Inter';
  static const String _displayFont = 'Syne';

  // Display
  static TextStyle displayLarge({required Color color, FontWeight weight = FontWeight.w900}) =>
      TextStyle(fontFamily: _displayFont, fontSize: 36, fontWeight: weight, color: color, letterSpacing: -1.5, height: 1.1);

  static TextStyle displayMedium({required Color color, FontWeight weight = FontWeight.w800}) =>
      TextStyle(fontFamily: _displayFont, fontSize: 28, fontWeight: weight, color: color, letterSpacing: -1.0, height: 1.2);

  static TextStyle displaySmall({required Color color, FontWeight weight = FontWeight.w800}) =>
      TextStyle(fontFamily: _displayFont, fontSize: 22, fontWeight: weight, color: color, letterSpacing: -0.5, height: 1.2);

  // Headline
  static TextStyle headlineLarge({required Color color, FontWeight weight = FontWeight.w800}) =>
      TextStyle(fontFamily: _displayFont, fontSize: 24, fontWeight: weight, color: color, letterSpacing: -0.8, height: 1.2);

  static TextStyle headlineMedium({required Color color, FontWeight weight = FontWeight.w700}) =>
      TextStyle(fontFamily: _displayFont, fontSize: 20, fontWeight: weight, color: color, letterSpacing: -0.5, height: 1.3);

  static TextStyle headlineSmall({required Color color, FontWeight weight = FontWeight.w700}) =>
      TextStyle(fontFamily: _displayFont, fontSize: 18, fontWeight: weight, color: color, letterSpacing: -0.3, height: 1.3);

  // Title
  static TextStyle titleLarge({required Color color, FontWeight weight = FontWeight.w700}) =>
      TextStyle(fontFamily: _primaryFont, fontSize: 18, fontWeight: weight, color: color, letterSpacing: -0.2, height: 1.4);

  static TextStyle titleMedium({required Color color, FontWeight weight = FontWeight.w600}) =>
      TextStyle(fontFamily: _primaryFont, fontSize: 16, fontWeight: weight, color: color, letterSpacing: 0, height: 1.4);

  static TextStyle titleSmall({required Color color, FontWeight weight = FontWeight.w600}) =>
      TextStyle(fontFamily: _primaryFont, fontSize: 14, fontWeight: weight, color: color, letterSpacing: 0.1, height: 1.4);

  // Body
  static TextStyle bodyLarge({required Color color, FontWeight weight = FontWeight.w500}) =>
      TextStyle(fontFamily: _primaryFont, fontSize: 16, fontWeight: weight, color: color, letterSpacing: 0, height: 1.5);

  static TextStyle bodyMedium({required Color color, FontWeight weight = FontWeight.w500}) =>
      TextStyle(fontFamily: _primaryFont, fontSize: 14, fontWeight: weight, color: color, letterSpacing: 0, height: 1.5);

  static TextStyle bodySmall({required Color color, FontWeight weight = FontWeight.w400}) =>
      TextStyle(fontFamily: _primaryFont, fontSize: 12, fontWeight: weight, color: color, letterSpacing: 0.1, height: 1.4);

  // Label
  static TextStyle labelLarge({required Color color, FontWeight weight = FontWeight.w600}) =>
      TextStyle(fontFamily: _primaryFont, fontSize: 14, fontWeight: weight, color: color, letterSpacing: 0.3, height: 1.3);

  static TextStyle labelMedium({required Color color, FontWeight weight = FontWeight.w600}) =>
      TextStyle(fontFamily: _primaryFont, fontSize: 12, fontWeight: weight, color: color, letterSpacing: 0.5, height: 1.3);

  static TextStyle labelSmall({required Color color, FontWeight weight = FontWeight.w700}) =>
      TextStyle(fontFamily: _primaryFont, fontSize: 10, fontWeight: weight, color: color, letterSpacing: 1.0, height: 1.2);
}

/// Reusable gradients
class AppGradients {
  static const LinearGradient brandGradient = LinearGradient(
    colors: [AppTokens.brandOrange, AppTokens.brandTeal],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient blueGradient = LinearGradient(
    colors: [AppTokens.brandBlue, AppTokens.brandPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkSurfaceGradient = LinearGradient(
    colors: [Color(0xFF1E1E1E), Color(0xFF2C2C2C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient lightSurfaceGradient = LinearGradient(
    colors: [Color(0xFFF8F9FA), Color(0xFFE9ECEF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient modeGradient(int mode, bool isDark) {
    switch (mode) {
      case 0:
        return LinearGradient(
          colors: isDark
              ? [const Color(0xFF00E5FF), const Color(0xFF3b82f6)]
              : [const Color(0xFF4361EE), const Color(0xFF3A0CA3)],
        );
      case 1:
        return const LinearGradient(
          colors: [AppTokens.trainColor, Color(0xFFE63946)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 2:
        return const LinearGradient(
          colors: [AppTokens.busColor, Color(0xFF2D6A4F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 3:
        return const LinearGradient(
          colors: [AppTokens.planeColor, AppTokens.brandIndigo],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 4:
        return const LinearGradient(
          colors: [AppTokens.roadColor, Color(0xFF118AB2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return brandGradient;
    }
  }
}
