import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/ssh_words.dart';

void main() {
  // Harm: "Connection closed by 203.0.113.9 port 22" reads as a fault to fix, when it only needs a wait.
  test('a connection closed before login says to wait, in every form ssh gives it', () {
    for (final said in <String>[
      'Connection closed by 203.0.113.9 port 22',
      'kex_exchange_identification: read: Connection reset by peer',
      'Connection reset by 203.0.113.9 port 22',
    ]) {
      expect(sshRefusalWords(said), contains('Wait a minute'), reason: said);
    }
  });

  test('other words stay ssh\'s own, and nothing stays nothing', () {
    expect(sshRefusalWords('Permission denied (publickey).'), 'Permission denied (publickey).');
    expect(sshRefusalWords(null), isNull);
  });
}
