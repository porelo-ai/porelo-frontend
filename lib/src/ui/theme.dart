import 'package:flutter/material.dart';

import 'tokens.dart';

/// The interface's two themes, in the look of Porelo's website, built from the tokens and nothing
/// else: its near-black ground and frosted surfaces in the dark one, the same hues darkened on a pale
/// ground in the light one.
abstract final class PoreloTheme {
  /// The light theme.
  static ThemeData get light => _build(_light);

  /// The dark theme.
  static ThemeData get dark => _build(_dark);

  /// The website's colours, its frosted glass laid opaque over the ground in four steps.
  static const ColorScheme _dark = ColorScheme(
    brightness: Brightness.dark,
    primary: Primitives.cyan,
    onPrimary: Primitives.ground,
    primaryContainer: Color(0xFF00474E),
    onPrimaryContainer: Color(0xFFA6F9FF),
    secondary: Primitives.magenta,
    onSecondary: Primitives.ground,
    secondaryContainer: Color(0xFF5A1149),
    onSecondaryContainer: Color(0xFFFFD0F4),
    tertiary: Primitives.lime,
    onTertiary: Primitives.ground,
    tertiaryContainer: Color(0xFF2C4410),
    onTertiaryContainer: Color(0xFFDDFFAD),
    error: Primitives.red,
    onError: Primitives.ground,
    errorContainer: Color(0xFF561020),
    onErrorContainer: Color(0xFFFFD0D8),
    surface: Primitives.ground,
    onSurface: Primitives.text,
    surfaceContainerLowest: Color(0xFF030308),
    surfaceContainerLow: Primitives.ground2,
    surfaceContainer: Color(0xFF0F1122),
    surfaceContainerHigh: Color(0xFF15172C),
    surfaceContainerHighest: Color(0xFF1C1F38),
    onSurfaceVariant: Primitives.muted,
    outline: Color(0xFF6E77A0),
    outlineVariant: Color(0xFF2A2F50),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Primitives.text,
    onInverseSurface: Primitives.ground2,
    inversePrimary: Primitives.petrol,
    surfaceTint: Colors.transparent,
  );

  /// The same hues darkened until they read on a pale blue-grey ground.
  static const ColorScheme _light = ColorScheme(
    brightness: Brightness.light,
    primary: Primitives.petrol,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFC2F6FA),
    onPrimaryContainer: Color(0xFF00262A),
    secondary: Primitives.deepMagenta,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFFFD5F3),
    onSecondaryContainer: Color(0xFF3A002D),
    tertiary: Primitives.olive,
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFD6F5A4),
    onTertiaryContainer: Color(0xFF112000),
    error: Primitives.deepRed,
    onError: Colors.white,
    errorContainer: Color(0xFFFFD9DF),
    onErrorContainer: Color(0xFF3F0011),
    surface: Primitives.paleGround,
    onSurface: Primitives.ground2,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Color(0xFFF0F2FA),
    surfaceContainer: Color(0xFFEAEDF7),
    surfaceContainerHigh: Color(0xFFE3E7F3),
    surfaceContainerHighest: Color(0xFFDCE1F0),
    onSurfaceVariant: Primitives.slate,
    outline: Primitives.steel,
    outlineVariant: Color(0xFFC9CFE3),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFF1C1F38),
    onInverseSurface: Primitives.text,
    inversePrimary: Primitives.cyan,
    surfaceTint: Colors.transparent,
  );

  static ThemeData _build(ColorScheme scheme) {
    const pill = StadiumBorder();
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Primitives.radiusMd),
      side: BorderSide(color: scheme.outlineVariant, width: Primitives.hairline),
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: scheme.surface,
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: scheme.primary, width: Primitives.focusLine),
        ),
        // Helper text takes its space up front rather than appearing and shifting what is below.
        helperMaxLines: 2,
        errorMaxLines: 3,
      ),
      cardTheme: CardThemeData(
        margin: const EdgeInsets.all(Primitives.space1),
        color: scheme.surfaceContainer,
        elevation: 0,
        shape: rounded,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Primitives.radiusLg),
          side: BorderSide(color: scheme.outlineVariant, width: Primitives.hairline),
        ),
      ),
      filledButtonTheme: const FilledButtonThemeData(style: ButtonStyle(shape: WidgetStatePropertyAll(pill))),
      outlinedButtonTheme: const OutlinedButtonThemeData(style: ButtonStyle(shape: WidgetStatePropertyAll(pill))),
      elevatedButtonTheme: const ElevatedButtonThemeData(style: ButtonStyle(shape: WidgetStatePropertyAll(pill))),
      textButtonTheme: const TextButtonThemeData(style: ButtonStyle(shape: WidgetStatePropertyAll(pill))),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(Primitives.radiusSm),
        ),
        textStyle: TextStyle(color: scheme.onInverseSurface),
      ),
    );
  }
}
