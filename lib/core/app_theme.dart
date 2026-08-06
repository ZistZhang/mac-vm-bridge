import 'package:flutter/material.dart';

class AppTheme {
  static const seed = Color(0xFF0F766E);
  static const accent = Color(0xFF14B8A6);
  static const ink = Color(0xFF0F172A);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      surface: const Color(0xFFF8FAFC),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF1F5F9),
      fontFamilyFallback: const ['PingFang SC', 'Microsoft YaHei', 'Noto Sans CJK SC'],
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.white,
        indicatorColor: scheme.primaryContainer,
        labelType: NavigationRailLabelType.all,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: scheme.primaryContainer,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: const Color(0xFF111827),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF020617),
      fontFamilyFallback: const ['PingFang SC', 'Microsoft YaHei', 'Noto Sans CJK SC'],
      cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
