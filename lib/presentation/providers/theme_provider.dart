import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../core/design_system.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  ThemeMode get resolvedThemeMode {
    if (_themeMode == ThemeMode.system) {
      final brightness = SchedulerBinding.instance.window.platformBrightness;
      return brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light;
    }
    return _themeMode;
  }

  bool get isDark => resolvedThemeMode == ThemeMode.dark;

  // ── BACKGROUND ──
  Color get backgroundColor => isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC);

  Color get surfaceColor => isDark ? const Color(0xFF161B22) : Colors.white;

  Color get surfaceVariantColor => isDark ? const Color(0xFF1E242C) : const Color(0xFFF1F5F9);

  // ── PRIMARY ──
  Color get primaryColor => isDark ? const Color(0xFF3B82F6) : const Color(0xFF1976D2);

  Color get onPrimaryColor => Colors.white;

  Color get primaryContainerColor => isDark ? const Color(0xFF1E3A5F) : const Color(0xFFD6E4FF);

  // ── SECONDARY ──
  Color get secondaryColor => isDark ? const Color(0xFF43AA8B) : const Color(0xFF2D6A4F);

  // ── TEXT ──
  Color get textColor => isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1E293B);

  Color get secondaryTextColor => isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B);

  Color get tertiaryTextColor => isDark ? const Color(0xFF484F58) : const Color(0xFF94A3B8);

  // ── BORDERS ──
  Color get borderColor => isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1);

  Color get dividerColor => isDark ? const Color(0xFF21262D) : const Color(0xFFE2E8F0);

  // ── SEMANTIC ──
  Color get successColor => isDark ? AppTokens.successDark : AppTokens.successLight;

  Color get warningColor => isDark ? AppTokens.warningDark : AppTokens.warningLight;

  Color get errorColor => isDark ? AppTokens.errorDark : AppTokens.errorLight;

  Color get infoColor => isDark ? AppTokens.infoDark : AppTokens.infoLight;

  // ── GLASSMORPHISM ──
  double get glassBlur => isDark ? AppTokens.glassBlurDark : AppTokens.glassBlurLight;

  double get glassOpacity => isDark ? AppTokens.glassOpacityDark : AppTokens.glassOpacityLight;

  Color get glassSurfaceColor => isDark
      ? Colors.white.withOpacity(0.05)
      : Colors.black.withOpacity(0.03);

  Color get glassBorderColor => isDark
      ? Colors.white.withOpacity(0.08)
      : Colors.black.withOpacity(0.06);

  // ── GRADIENTS ──
  Gradient get progressGradient => isDark
      ? const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF00E5FF)])
      : const LinearGradient(colors: [Color(0xFF1976D2), Color(0xFF43AA8B)]);

  Gradient get primaryGradient => isDark
      ? const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF1E3A5F)])
      : const LinearGradient(colors: [Color(0xFF1976D2), Color(0xFFD6E4FF)]);

  Gradient get surfaceGradient => isDark
      ? const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E242C), Color(0xFF161B22)],
        )
      : const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF8FAFC)],
        );

  // ── SHADOWS ──
  List<BoxShadow> get cardShadow => isDark
      ? [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4)),
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4, offset: const Offset(0, 1)),
        ]
      : [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4)),
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 1)),
        ];

  List<BoxShadow> get elevatedShadow => isDark
      ? [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 32, offset: const Offset(0, 8)),
        ]
      : [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 32, offset: const Offset(0, 8)),
        ];

  // ── MODE COLORS ──
  static Color modeColor(int mode) {
    switch (mode) {
      case 0:
        return AppTokens.homeColor;
      case 1:
        return AppTokens.trainColor;
      case 2:
        return AppTokens.busColor;
      case 3:
        return AppTokens.planeColor;
      case 4:
        return AppTokens.roadColor;
      default:
        return AppTokens.homeColor;
    }
  }

  static IconData modeIcon(int mode) {
    switch (mode) {
      case 0:
        return Icons.grid_view_rounded;
      case 1:
        return Icons.train_rounded;
      case 2:
        return Icons.directions_bus_rounded;
      case 3:
        return Icons.flight_takeoff_rounded;
      case 4:
        return Icons.route;
      default:
        return Icons.grid_view_rounded;
    }
  }

  // ── STATUS COLORS ──
  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'on time':
      case 'puntuale':
      case 'regolare':
      case 'in orario':
        return successColor;
      case 'delayed':
      case 'ritardo':
      case 'in ritardo':
        return warningColor;
      case 'cancelled':
      case 'cancellato':
      case 'soppresso':
        return errorColor;
      case 'arrived':
      case 'arrivato':
      case 'partito':
        return infoColor;
      default:
        return secondaryTextColor;
    }
  }
}
