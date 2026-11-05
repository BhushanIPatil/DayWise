import 'dart:math' as math;

import 'package:flutter/material.dart';

class Brand {
  static const Color income = Color(0xFF12B886);
  static const Color expense = Color(0xFFFF4D6D);

  static const List<Color> accents = [
    Color(0xFF6C5CE7), // violet
    Color(0xFF0984E3), // blue
    Color(0xFF00B894), // mint
    Color(0xFFFF7675), // coral
    Color(0xFFFD9644), // orange
    Color(0xFFE84393), // pink
  ];
}

Color tint(Color c, double opacity) =>
    c.withAlpha((math.min(1.0, math.max(0.0, opacity)) * 255).round());

LinearGradient accentGradient(Color c) {
  final hsl = HSLColor.fromColor(c);
  final second = hsl
      .withHue((hsl.hue + 38) % 360)
      .withLightness(math.min(1.0, math.max(0.0, hsl.lightness * 0.85)))
      .toColor();
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [c, second],
  );
}

extension ThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get cs => Theme.of(this).colorScheme;
  TextTheme get tt => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get cardColor =>
      isDark ? const Color(0xFF181A22) : const Color(0xFFFFFFFF);
  Color get softFill =>
      isDark ? const Color(0xFF22252F) : const Color(0xFFF0EEF8);
}

ThemeData buildTheme(Brightness brightness, Color accent) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: brightness)
      .copyWith(
    primary: accent,
    onPrimary: Colors.white,
    surface: dark ? const Color(0xFF15161D) : Colors.white,
  );
  final bg = dark ? const Color(0xFF0C0D12) : const Color(0xFFF4F3FA);

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'PlusJakartaSans',
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: scheme.onSurface,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.w800,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF22252F) : const Color(0xFFF0EEF8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    dividerColor: dark ? const Color(0x14FFFFFF) : const Color(0x14000000),
  );
}
