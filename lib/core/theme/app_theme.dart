import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121212),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFBB86FC),
        secondary: Color(0xFF03DAC6),
        surface: Color(0xFF121212),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: const Color(0xFFBB86FC).withAlpha(40),
        backgroundColor: const Color(0xFF1E1E1E),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF6200EE),
        secondary: Color(0xFF03DAC6),
        surface: Color(0xFFFFFFFF),
      ),
    );
  }
}
