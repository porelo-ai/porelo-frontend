import 'package:flutter/material.dart';

import 'tokens.dart';

/// The interface's two themes, built from the tokens and nothing else — the same way melkheftken
/// builds its own, so the two look like one family.
abstract final class PoreloTheme {
  /// The light theme.
  static ThemeData get light => _build(Brightness.light);

  /// The dark theme.
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Primitives.brandIndigo600,
          brightness: brightness,
        ),
        useMaterial3: true,
        visualDensity: VisualDensity.standard,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          // Helper text takes its space up front rather than appearing and shifting what is below.
          helperMaxLines: 2,
          errorMaxLines: 3,
        ),
        cardTheme: CardThemeData(
          margin: const EdgeInsets.all(Primitives.space1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Primitives.radiusMd),
          ),
        ),
      );
}
