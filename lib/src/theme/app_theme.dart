import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() => _base(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6D5DF6),
          brightness: Brightness.light,
        ),
      );

  static ThemeData dark() => _base(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8EA2FF),
          brightness: Brightness.dark,
        ),
      );

  static ThemeData _base({required ColorScheme colorScheme}) {
    const shapes = ShapeTokens();
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      fontFamily: 'Roboto',
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        },
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainer,
        surfaceTintColor: colorScheme.surfaceTint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(shapes.extraLarge)),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(shapes.large)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(shapes.large)),
          side: BorderSide(color: colorScheme.outlineVariant),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.62),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(shapes.large),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(shapes.large),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(shapes.large),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 76,
        backgroundColor: colorScheme.surfaceContainer.withValues(alpha: 0.92),
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(shapes.full)),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(shapes.extraLarge)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(shapes.medium)),
      ),
    );
  }
}

class ShapeTokens {
  const ShapeTokens();

  double get small => 12;
  double get medium => 18;
  double get large => 24;
  double get extraLarge => 32;
  double get full => 999;
}
