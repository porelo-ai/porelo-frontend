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

  // Harm: a give-up's answer is lost where it wrapped, or where a refusal was said after it, and the person is told
  // nothing of the keys it removed.
  test('a JSON answer is read whole where it wrapped, also with a line said after it', () {
    final terminal = Terminal(maxLines: 100)..resize(20, 10);
    const answer = '{"removed":[{"project":null,"repository":"organization"}],"kept":[]}';
    terminal.write('Central forge token: \r\n$answer\r\nporelo: the identity of orchard changed\r\n');
    expect(readJsonAnswer(terminal), answer);
  });

  test('a screen with no JSON object answers none', () {
    final terminal = Terminal(maxLines: 100)..resize(40, 10);
    terminal.write('porelo: the vault is shut\r\n[1, 2]\r\n');
    expect(readJsonAnswer(terminal), isNull);
  });

  // Harm: another object printed after the answer is taken for it, and the person is told nothing was removed.
  test('the answer is the last object that holds what it must, not a later one', () {
    final terminal = Terminal(maxLines: 100)..resize(40, 10);
    const answer = '{"removed":[],"kept":[]}';
    terminal.write('$answer\r\n{"note":"later"}\r\n');
    expect(readJsonAnswer(terminal, holding: const ['removed', 'kept']), answer);
  });

  // Harm: an object larger than any answer is decoded whole, in the window's memory.
  test('an object larger than its limit is not read', () {
    final terminal = Terminal(maxLines: 1000)..resize(80, 10);
    terminal.write('{"removed":[],"kept":[],"x":"${'x' * 2000}"}\r\n');
    expect(readJsonAnswer(terminal, most: 1000), isNull);
  });
}
