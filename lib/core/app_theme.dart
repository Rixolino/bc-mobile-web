import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Color(0xFF1E1E1E),
    primaryColor: Color(0xFF2196F3),
    colorScheme: ColorScheme.dark(
      primary: Color(0xFF2196F3),
      secondary: Color(0xFF03DAC6),
      surface: Color(0xFF2C2C2C),
    ),
    textTheme: GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme,
    ),
    useMaterial3: true,
  );

  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
    primaryColor: Color(0xFF1976D2),
    colorScheme: ColorScheme.light(
      primary: Color(0xFF1976D2),
      secondary: Color(0xFF00ACC1),
      surface: Colors.grey[100]!,
    ),
    textTheme: GoogleFonts.interTextTheme(
      ThemeData.light().textTheme,
    ),
    useMaterial3: true,
  );
}
