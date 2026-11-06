import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

/// A row as it shows, an empty cell as the space it is.
String _row(Terminal terminal, int row) {
  final line = terminal.buffer.lines[row];
  return String.fromCharCodes([
    for (var i = 0; i < line.length; i++) line.getCodePoint(i) == 0 ? 0x20 : line.getCodePoint(i),
  ]);
}

/// What tmux sends to clear the start of a line it redraws, as an indented line of a transcript.
///
/// The harm: a character of an earlier line left before an indented one, so an agent's transcript
/// reads as something it did not say.
void main() {
  test('erasing to the cursor (EL 1) takes the cursor’s own cell, as tmux clears an indent', () {
    final terminal = Terminal(maxLines: 100)..resize(20, 3);
    terminal.write('Note: done\r\n');
    // tmux's clear of the first two cells: the cursor on the last of them, then EL 1.
    terminal.write('\x1b[1;2H\x1b[1K\x1b[1;3H"decision"');

    expect(_row(terminal, 0).trimRight(), '  "decision"');
  });

  test('erasing the screen to the cursor (ED 1) takes the cursor’s own cell too', () {
    final terminal = Terminal(maxLines: 100)..resize(20, 3);
    terminal.write('first\r\nsecond');
    terminal.write('\x1b[2;3H\x1b[1J');

    expect(_row(terminal, 0).trim(), isEmpty);
    expect(_row(terminal, 1).trimRight(), '   ond');
  });
}
