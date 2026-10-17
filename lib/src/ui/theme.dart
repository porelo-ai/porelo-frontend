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
    primaryContainer: Primitives.cyanContainer,
    onPrimaryContainer: Primitives.onCyanContainer,
    secondary: Primitives.magenta,
    onSecondary: Primitives.ground,
    secondaryContainer: Primitives.magentaContainer,
    onSecondaryContainer: Primitives.onMagentaContainer,
    tertiary: Primitives.lime,
    onTertiary: Primitives.ground,
    tertiaryContainer: Primitives.limeContainer,
    onTertiaryContainer: Primitives.onLimeContainer,
    error: Primitives.red,
    onError: Primitives.ground,
    errorContainer: Primitives.redContainer,
    onErrorContainer: Primitives.onRedContainer,
    surface: Primitives.ground,
    onSurface: Primitives.text,
    surfaceContainerLowest: Primitives.groundLowest,
    surfaceContainerLow: Primitives.ground2,
    surfaceContainer: Primitives.glass1,
    surfaceContainerHigh: Primitives.glass2,
    surfaceContainerHighest: Primitives.glass3,
    onSurfaceVariant: Primitives.muted,
    outline: Primitives.dusk,
    outlineVariant: Primitives.glassBorder,
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
    primaryContainer: Primitives.petrolContainer,
    onPrimaryContainer: Primitives.onPetrolContainer,
    secondary: Primitives.deepMagenta,
    onSecondary: Colors.white,
    secondaryContainer: Primitives.deepMagentaContainer,
    onSecondaryContainer: Primitives.onDeepMagentaContainer,
    tertiary: Primitives.olive,
    onTertiary: Colors.white,
    tertiaryContainer: Primitives.oliveContainer,
    onTertiaryContainer: Primitives.onOliveContainer,
    error: Primitives.deepRed,
    onError: Colors.white,
    errorContainer: Primitives.deepRedContainer,
    onErrorContainer: Primitives.onDeepRedContainer,
    surface: Primitives.paleGround,
    onSurface: Primitives.ground2,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Primitives.pale1,
    surfaceContainer: Primitives.pale2,
    surfaceContainerHigh: Primitives.pale3,
    surfaceContainerHighest: Primitives.pale4,
    onSurfaceVariant: Primitives.slate,
    outline: Primitives.steel,
    outlineVariant: Primitives.paleBorder,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Primitives.glass3,
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
