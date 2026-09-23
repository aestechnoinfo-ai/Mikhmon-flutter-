import 'package:flutter/material.dart';

/// Simple contrôleur de thème (clair / sombre / système).
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController(super.initial);
}

/// Contrôleur de thème global de l'application.
final ThemeController themeController = ThemeController(ThemeMode.system);

ThemeData _base(ColorScheme scheme) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: scheme.surface,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(),
    dividerTheme: DividerThemeData(space: 1),
  );
}

/// Thème clair de l'application (fond au vert/bleu Mikhmon).
ThemeData buildLightTheme() =>
    _base(ColorScheme.fromSeed(seedColor: const Color(0xFF00875A), brightness: Brightness.light));

/// Thème sombre.
ThemeData buildDarkTheme() =>
    _base(ColorScheme.fromSeed(seedColor: const Color(0xFF2A9D8F), brightness: Brightness.dark));