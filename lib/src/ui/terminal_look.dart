import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import 'tokens.dart';

/// How something that shows what an agent writes looks: like the terminal a person works in, by
/// hand, whatever the window's theme (walk 9). One palette, in Porelo's colours and dark in both
/// modes, for every terminal the interface draws, so the small console on a tile and the session
/// look alike.
abstract final class TerminalLook {
  /// The terminal's colours, for every `TerminalView` the interface draws.
  static const TerminalTheme theme = TerminalTheme(
    cursor: Primitives.cyan,
    selection: Color(0x5500F0FF),
    foreground: Primitives.text,
    background: Primitives.ground2,
    black: Primitives.ground,
    red: Primitives.red,
    green: Primitives.lime,
    yellow: Primitives.amber,
    blue: Color(0xFF6E8BFF),
    magenta: Primitives.magenta,
    cyan: Primitives.cyan,
    white: Color(0xFFC9D0F0),
    brightBlack: Color(0xFF6E77A0),
    brightRed: Color(0xFFFF8FA2),
    brightGreen: Color(0xFFD4FF8A),
    brightYellow: Color(0xFFFFCB6B),
    brightBlue: Color(0xFF9DB0FF),
    brightMagenta: Color(0xFFFF7AE5),
    brightCyan: Color(0xFF7CF9FF),
    brightWhite: Colors.white,
    searchHitBackground: Primitives.amber,
    searchHitBackgroundCurrent: Primitives.lime,
    searchHitForeground: Primitives.ground,
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
