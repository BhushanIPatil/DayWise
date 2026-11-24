import 'dart:math' as math;

import 'package:flutter/material.dart';

class Brand {
  static const double cardRadius = 12;
  static const double controlRadius = 8;
  static const double sheetRadius = 16;
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
  const controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(Brand.controlRadius)),
  );
  const cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(Brand.cardRadius)),
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'PlusJakartaSans',
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    cardTheme: const CardThemeData(shape: cardShape),
    dialogTheme: const DialogThemeData(shape: cardShape),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Brand.sheetRadius),
        ),
      ),
    ),
    popupMenuTheme: const PopupMenuThemeData(shape: controlShape),
    menuTheme: const MenuThemeData(
      style: MenuStyle(shape: WidgetStatePropertyAll(controlShape)),
    ),
    dropdownMenuTheme: const DropdownMenuThemeData(
      menuStyle: MenuStyle(shape: WidgetStatePropertyAll(controlShape)),
    ),
    chipTheme: const ChipThemeData(shape: controlShape),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: controlShape),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(shape: controlShape),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(shape: controlShape),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: controlShape),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(shape: controlShape),
    ),
    segmentedButtonTheme: const SegmentedButtonThemeData(
      style: ButtonStyle(shape: WidgetStatePropertyAll(controlShape)),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      shape: cardShape,
    ),
    datePickerTheme: const DatePickerThemeData(
      shape: cardShape,
      rangePickerShape: cardShape,
    ),
    timePickerTheme: const TimePickerThemeData(
      shape: cardShape,
      hourMinuteShape: controlShape,
      dayPeriodShape: controlShape,
    ),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Brand.controlRadius),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Brand.controlRadius),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Brand.controlRadius),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Brand.controlRadius),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Brand.controlRadius),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Brand.controlRadius),
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Brand.controlRadius),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    ),
    dividerColor: dark ? const Color(0x14FFFFFF) : const Color(0x14000000),
  );
}
