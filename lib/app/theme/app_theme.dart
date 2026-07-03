import 'package:flutter/material.dart';

class AppTheme {
  static const Color brandColor = Color(0xFFA70E07);

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(seedColor: brandColor);

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        centerTitle: true,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
      ),
    );
  }
}
