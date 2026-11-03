import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/unlock_terminal.dart';
import 'package:xterm/xterm.dart';

String _shown(Terminal terminal) =>
    [for (var row = 0; row < terminal.buffer.lines.length; row++) terminal.buffer.lines[row].getText()]
        .join('\n')
        .trim();

void main() {
  // The harm: a failure whose only words are wiped, or an answer that is left where the person must read it.
  test('a JSON answer leaves the screen, also where it wrapped, and what stood before it stays', () {
    final terminal = Terminal(maxLines: 100)..resize(20, 10);
    terminal.write('Passphrase:\r\n{"fingerprint":"SHA256:abcdefghijklmnopqrstuvwxyz"}\r\n');

    eraseJsonAnswer(terminal);

    expect(_shown(terminal), 'Passphrase:');
  });

  test('a JSON answer longer than the screen leaves it too, scrolled past rows included', () {
    final terminal = Terminal(maxLines: 100)..resize(10, 3);
    terminal.write('{"long":"${'x' * 80}"}\r\n');

    eraseJsonAnswer(terminal);

    expect(_shown(terminal), isEmpty);
  });

  test('a last line that is no JSON object stays on the screen', () {
    for (final words in ['ssh-keygen failed: no such file', '{not json', '[1, 2]']) {
      final terminal = Terminal(maxLines: 100)..resize(40, 10);
      terminal.write('$words\r\n');

      eraseJsonAnswer(terminal);

      expect(_shown(terminal), words);
    }
  });
}
