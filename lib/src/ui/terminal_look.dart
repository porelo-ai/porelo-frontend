import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import 'tokens.dart';

/// How something that shows what an agent writes looks: like the terminal a person works in, by
/// hand (walk 9). A console of a piece of work follows the window's light or dark, through [consoleOf]
/// and [themeOf], so the small one on a row and the session look alike; a terminal in a dialog keeps
/// the dark [theme].
abstract final class TerminalLook {
  /// The colours of a terminal in a dialog.
  static const TerminalTheme theme = TerminalTheme(
    cursor: Primitives.cyan,
    selection: Primitives.cyanSelection,
    foreground: Primitives.text,
    background: Primitives.ground2,
    black: Primitives.ground,
    red: Primitives.red,
    green: Primitives.lime,
    yellow: Primitives.amber,
    blue: Primitives.terminalBlue,
    magenta: Primitives.magenta,
    cyan: Primitives.cyan,
    white: Primitives.terminalWhite,
    brightBlack: Primitives.dusk,
    brightRed: Primitives.brightRed,
    brightGreen: Primitives.brightLime,
    brightYellow: Primitives.brightAmber,
    brightBlue: Primitives.brightBlue,
    brightMagenta: Primitives.brightMagenta,
    brightCyan: Primitives.brightCyan,
    brightWhite: Colors.white,
    searchHitBackground: Primitives.amber,
    searchHitBackgroundCurrent: Primitives.lime,
    searchHitForeground: Primitives.ground,
  );

  /// A session's colours on the dark console.
  static const TerminalTheme darkConsole = TerminalTheme(
    cursor: Primitives.cyan,
    selection: Primitives.cyanSelection,
    foreground: Primitives.text,
    background: Primitives.ground,
    black: Primitives.ground,
    red: Primitives.red,
    green: Primitives.lime,
    yellow: Primitives.amber,
    blue: Primitives.terminalBlue,
    magenta: Primitives.magenta,
    cyan: Primitives.cyan,
    white: Primitives.terminalWhite,
    brightBlack: Primitives.dusk,
    brightRed: Primitives.brightRed,
    brightGreen: Primitives.brightLime,
    brightYellow: Primitives.brightAmber,
    brightBlue: Primitives.brightBlue,
    brightMagenta: Primitives.brightMagenta,
    brightCyan: Primitives.brightCyan,
    brightWhite: Colors.white,
    searchHitBackground: Primitives.amber,
    searchHitBackgroundCurrent: Primitives.lime,
    searchHitForeground: Primitives.ground,
  );

  /// A session's colours on the light console: the same hues darkened until they read on white, and
  /// its white and bright white darkened too, since an agent writes in them expecting a dark ground.
  static const TerminalTheme lightConsole = TerminalTheme(
    cursor: Primitives.petrol,
    selection: Color(0x55006872),
    foreground: Color(0xFF1E2440),
    background: Color(0xFFFFFFFF),
    black: Color(0xFF0B0B1A),
    red: Primitives.deepRed,
    green: Color(0xFF2F5200),
    yellow: Primitives.brown,
    blue: Color(0xFF1F3FB8),
    magenta: Primitives.deepMagenta,
    cyan: Primitives.petrol,
    white: Color(0xFF565E80),
    brightBlack: Color(0xFF565E80),
    brightRed: Color(0xFFA30F34),
    brightGreen: Primitives.olive,
    brightYellow: Color(0xFF7A4900),
    brightBlue: Color(0xFF2A4BC4),
    brightMagenta: Color(0xFF8E0F6E),
    brightCyan: Color(0xFF005A63),
    brightWhite: Color(0xFF0B0B1A),
    searchHitBackground: Primitives.amber,
    searchHitBackgroundCurrent: Primitives.lime,
    searchHitForeground: Color(0xFF0B0B1A),
  );

  /// The console's colours for the window's light or dark.
  static ConsoleColours consoleOf(BuildContext context) => ConsoleColours.of(Theme.of(context).brightness);

  /// A session's colours for the window's light or dark.
  static TerminalTheme themeOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkConsole : lightConsole;

  /// The colours an agent's escapes map to on the console; what `ansiSpans` is given.
  static ColorScheme coloursOf(BuildContext context) {
    final terminal = themeOf(context);
    final console = consoleOf(context);
    return ColorScheme.fromSeed(seedColor: terminal.cyan, brightness: Theme.of(context).brightness).copyWith(
      surface: console.background,
      onSurface: console.text,
      onSurfaceVariant: console.muted,
      error: console.error,
      primary: console.ok,
      tertiary: terminal.yellow,
      secondary: terminal.blue,
    );
  }

  /// The console's text, monospace, at [size].
  static TextStyle textOf(BuildContext context, {double size = Sizes.terminalText}) => TextStyle(
    fontFamily: 'monospace',
    fontSize: size,
    color: consoleOf(context).text,
    height: Sizes.terminalLineHeight,
  );

  /// The terminal's background.
  static const Color background = Primitives.ground2;

  /// Its plain text.
  static const Color foreground = Primitives.text;

  /// Its text, monospace, at [size].
  static TextStyle text({double size = Sizes.terminalText}) =>
      TextStyle(fontFamily: 'monospace', fontSize: size, color: foreground, height: Sizes.terminalLineHeight);

  /// The colours an agent's escapes map to, as the terminal draws them; what `ansiSpans` is given.
  static final ColorScheme colours = ColorScheme.dark(
    surface: theme.background,
    onSurface: theme.foreground,
    onSurfaceVariant: theme.brightBlack,
    error: theme.red,
    primary: theme.green,
    tertiary: theme.yellow,
    secondary: theme.blue,
  );
}
