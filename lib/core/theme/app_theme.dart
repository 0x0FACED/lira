import 'package:flutter/material.dart';

class AppTheme {
  // Force pointer cursor on all interactive widgets so that Text children
  // inside buttons don't flip the cursor to I-beam on desktop.
  static const _clickCursor =
      WidgetStatePropertyAll(SystemMouseCursors.click);

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
      // Navigation bar is custom glass widget in MainShell
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(mouseCursor: _clickCursor),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(mouseCursor: _clickCursor),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(mouseCursor: _clickCursor),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(mouseCursor: _clickCursor),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(mouseCursor: _clickCursor),
      ),
      listTileTheme: ListTileThemeData(
        mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
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
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(mouseCursor: _clickCursor),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(mouseCursor: _clickCursor),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(mouseCursor: _clickCursor),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(mouseCursor: _clickCursor),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(mouseCursor: _clickCursor),
      ),
      listTileTheme: ListTileThemeData(
        mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
      ),
    );
  }
}
