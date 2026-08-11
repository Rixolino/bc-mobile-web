import 'package:flutter/material.dart';
import 'design_system.dart';

class AppTheme {
  // ── DARK THEME ──
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFF0D1117),
    primaryColor: const Color(0xFF3B82F6),
    fontFamily: 'Inter',

    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF3B82F6),
      primaryContainer: Color(0xFF1E3A5F),
      onPrimaryContainer: Color(0xFFD6E4FF),
      secondary: Color(0xFF43AA8B),
      secondaryContainer: Color(0xFF1A3A30),
      onSecondaryContainer: Color(0xFFB2F5EA),
      tertiary: Color(0xFFFF6B35),
      surface: Color(0xFF161B22),
      surfaceContainerHighest: Color(0xFF1E242C),
      surfaceContainerHigh: Color(0xFF21262D),
      surfaceContainer: Color(0xFF282E36),
      onSurface: Color(0xFFE6EDF3),
      onSurfaceVariant: Color(0xFF8B949E),
      outline: Color(0xFF30363D),
      outlineVariant: Color(0xFF21262D),
      error: Color(0xFFFF6B6B),
      errorContainer: Color(0xFF3D1F1F),
      onErrorContainer: Color(0xFFFFDAD6),
      inverseSurface: Color(0xFFE6EDF3),
      inversePrimary: Color(0xFF1976D2),
    ),

    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1.5, color: Color(0xFFE6EDF3), fontFamily: 'Syne'),
      displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -1.0, color: Color(0xFFE6EDF3), fontFamily: 'Syne'),
      displaySmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: Color(0xFFE6EDF3), fontFamily: 'Syne'),
      headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: Color(0xFFE6EDF3), fontFamily: 'Syne'),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: Color(0xFFE6EDF3), fontFamily: 'Syne'),
      headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: Color(0xFFE6EDF3), fontFamily: 'Syne'),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFFE6EDF3)),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFE6EDF3)),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFE6EDF3)),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFFE6EDF3)),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFE6EDF3)),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Color(0xFF8B949E)),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFE6EDF3)),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8B949E)),
      labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: Color(0xFF8B949E)),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0D1117),
      foregroundColor: Color(0xFFE6EDF3),
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
    ),

    cardTheme: CardThemeData(
      color: const Color(0xFF161B22),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        side: const BorderSide(color: Color(0xFF21262D), width: 1),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, AppTokens.minButtonHeight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusLg)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, AppTokens.minButtonHeight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusLg)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF3B82F6),
        minimumSize: const Size(AppTokens.minTouchTarget, AppTokens.minTouchTarget),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF21262D),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        borderSide: const BorderSide(color: Color(0xFF30363D)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        borderSide: const BorderSide(color: Color(0xFF30363D)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
      ),
      hintStyle: const TextStyle(color: Color(0xFF484F58)),
      labelStyle: const TextStyle(color: Color(0xFF8B949E)),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF21262D),
      selectedColor: const Color(0xFF3B82F6),
      labelStyle: const TextStyle(color: Color(0xFFE6EDF3), fontSize: 13, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
      side: const BorderSide(color: Color(0xFF30363D)),
    ),

    dividerTheme: const DividerThemeData(
      color: Color(0xFF21262D),
      thickness: 1,
      space: 1,
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return const Color(0xFF3B82F6);
        return const Color(0xFF484F58);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return const Color(0xFF1E3A5F);
        return const Color(0xFF30363D);
      }),
    ),

    sliderTheme: SliderThemeData(
      activeTrackColor: const Color(0xFF3B82F6),
      inactiveTrackColor: const Color(0xFF30363D),
      thumbColor: const Color(0xFF3B82F6),
      overlayColor: const Color(0xFF3B82F6).withOpacity(0.1),
      trackHeight: 4.0,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 20.0),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF1E242C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radius2Xl)),
      elevation: AppTokens.elevation5,
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF161B22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.radius3Xl)),
      ),
      elevation: AppTokens.elevation5,
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF161B22),
      indicatorColor: const Color(0xFF3B82F6).withOpacity(0.2),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      iconTheme: WidgetStateProperty.all(
        const IconThemeData(size: 24),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF21262D),
      contentTextStyle: const TextStyle(color: Color(0xFFE6EDF3)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
      behavior: SnackBarBehavior.floating,
    ),
  );

  // ── LIGHT THEME ──
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    primaryColor: const Color(0xFF1976D2),
    fontFamily: 'Inter',

    colorScheme: const ColorScheme.light(
      primary: Color(0xFF1976D2),
      primaryContainer: Color(0xFFD6E4FF),
      onPrimaryContainer: Color(0xFF001D36),
      secondary: Color(0xFF2D6A4F),
      secondaryContainer: Color(0xFFB2F5EA),
      onSecondaryContainer: Color(0xFF002111),
      tertiary: Color(0xFFE76F51),
      surface: Color(0xFFFFFFFF),
      surfaceContainerHighest: Color(0xFFF1F5F9),
      surfaceContainerHigh: Color(0xFFE2E8F0),
      surfaceContainer: Color(0xFFE8ECF0),
      onSurface: Color(0xFF1E293B),
      onSurfaceVariant: Color(0xFF64748B),
      outline: Color(0xFFCBD5E1),
      outlineVariant: Color(0xFFE2E8F0),
      error: Color(0xFFDC2626),
      errorContainer: Color(0xFFFEE2E2),
      onErrorContainer: Color(0xFF7F1D1D),
      inverseSurface: Color(0xFF1E293B),
      inversePrimary: Color(0xFF93C5FD),
    ),

    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1.5, color: Color(0xFF1E293B), fontFamily: 'Syne'),
      displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -1.0, color: Color(0xFF1E293B), fontFamily: 'Syne'),
      displaySmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: Color(0xFF1E293B), fontFamily: 'Syne'),
      headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: Color(0xFF1E293B), fontFamily: 'Syne'),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: Color(0xFF1E293B), fontFamily: 'Syne'),
      headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: Color(0xFF1E293B), fontFamily: 'Syne'),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Color(0xFF64748B)),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
      labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: Color(0xFF64748B)),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF8FAFC),
      foregroundColor: Color(0xFF1E293B),
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
    ),

    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, AppTokens.minButtonHeight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusLg)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, AppTokens.minButtonHeight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusLg)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF1976D2),
        minimumSize: const Size(AppTokens.minTouchTarget, AppTokens.minTouchTarget),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF1F5F9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
      ),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      labelStyle: const TextStyle(color: Color(0xFF64748B)),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFF1F5F9),
      selectedColor: const Color(0xFF1976D2),
      labelStyle: const TextStyle(color: Color(0xFF1E293B), fontSize: 13, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
      side: const BorderSide(color: Color(0xFFCBD5E1)),
    ),

    dividerTheme: const DividerThemeData(
      color: Color(0xFFE2E8F0),
      thickness: 1,
      space: 1,
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return const Color(0xFF1976D2);
        return const Color(0xFF94A3B8);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return const Color(0xFFD6E4FF);
        return const Color(0xFFE2E8F0);
      }),
    ),

    sliderTheme: SliderThemeData(
      activeTrackColor: const Color(0xFF1976D2),
      inactiveTrackColor: const Color(0xFFE2E8F0),
      thumbColor: const Color(0xFF1976D2),
      overlayColor: const Color(0xFF1976D2).withOpacity(0.1),
      trackHeight: 4.0,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 20.0),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radius2Xl)),
      elevation: AppTokens.elevation5,
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.radius3Xl)),
      ),
      elevation: AppTokens.elevation5,
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFF1976D2).withOpacity(0.1),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      iconTheme: WidgetStateProperty.all(
        const IconThemeData(size: 24),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF1E293B),
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
