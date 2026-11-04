import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/console_lines.dart';
import 'package:porelo_frontend/src/ui/terminal_look.dart';
import 'package:porelo_frontend/src/ui/tokens.dart';
import 'package:xterm/xterm.dart';

double _contrast(Color a, Color b) {
  final (one, other) = (a.computeLuminance(), b.computeLuminance());
  return (one > other ? one + 0.05 : other + 0.05) / (one > other ? other + 0.05 : one + 0.05);
}

void main() {
  // Harm: a success said as a failure, or a failure not marked, misleads whoever reads the console.
  test('a line is marked by what it says, and no failures is no error', () {
    expect(markOf('# Update the install page'), LineMark.heading);
    expect(markOf('❯ Port the import job'), LineMark.heading);
    expect(markOf('Connection to registry.example.test:443 refused by the sandbox'), LineMark.error);
    expect(markOf('\u001B[31mERROR\u001B[0m could not resolve'), LineMark.error);
    expect(markOf('  Tests run: 412, Failures: 0'), LineMark.result);
    expect(markOf('0 errors'), LineMark.result);
    expect(markOf('✻ Finished at 09:02'), LineMark.result);
    expect(markOf('I read doc/install.md and the three pages'), LineMark.plain);
  });

  // Harm: an agent's lines in a colour nobody can read on the console's ground.
  group('every colour reads on its console', () {
    void reads(String name, TerminalTheme theme, ConsoleColours console) => test(name, () {
      expect(theme.background, console.background);
      for (final each in <Color>[
        theme.foreground,
        theme.red,
        theme.green,
        theme.yellow,
        theme.blue,
        theme.magenta,
        theme.cyan,
        theme.white,
        theme.brightRed,
        theme.brightGreen,
        theme.brightYellow,
        theme.brightBlue,
        theme.brightMagenta,
        theme.brightCyan,
        console.text,
        console.strong,
        console.muted,
        console.ok,
        console.error,
      ]) {
        expect(_contrast(each, console.background), greaterThanOrEqualTo(4.5), reason: '$each');
      }
      expect(_contrast(console.noteText, console.noteBackground), greaterThanOrEqualTo(4.5));
    });
    reads('dark', TerminalLook.darkConsole, ConsoleColours.dark);
    reads('light', TerminalLook.lightConsole, ConsoleColours.light);
  });
}
