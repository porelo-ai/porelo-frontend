import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import 'tokens.dart';

/// How something that shows what an agent writes looks: like the terminal a person works in, by
/// hand (walk 9). What a terminal or an agent's log shows stays dark in the light theme too, as in a
/// console, through [screen] and [themeOf]; the bars around it follow the window, through [consoleOf].
/// A terminal in a dialog keeps the dark [theme].
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
  /// The colours of what a terminal or an agent's log shows: dark in the light theme too.
  static const ConsoleColours screen = ConsoleColours.dark;

  /// The console's colours for the window's light or dark.
  static ConsoleColours consoleOf(BuildContext context) => ConsoleColours.of(Theme.of(context).brightness);

  /// A session's colours, dark in the light theme too. [context] stays for those who read it from one.
  static TerminalTheme themeOf(BuildContext context) => darkConsole;

  /// The colours an agent's escapes map to on the console; what `ansiSpans` is given.
  static ColorScheme coloursOf(BuildContext context) {
    final terminal = themeOf(context);
    const console = screen;
    return ColorScheme.fromSeed(seedColor: terminal.cyan, brightness: Brightness.dark).copyWith(
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
  static TextStyle textOf(BuildContext context, {double size = Sizes.terminalText}) =>
      TextStyle(fontFamily: 'monospace', fontSize: size, color: screen.text, height: Sizes.terminalLineHeight);

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
