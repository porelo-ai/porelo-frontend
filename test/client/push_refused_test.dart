import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

/// Reading a forward refused for its key, and a key tried alone.
///
/// The harm: the address read wrong keeps a key for a place nobody chose, and a trial read as taken
/// when the forge never said so sends a person to keep a key that will be refused again.
void main() {
  test('a refusal is read field by field, its command as the arguments given', () {
    final read = PushRefused.from(<String, dynamic>{
      'outcome': 'PUSH_REFUSED',
      'address': 'ssh://git@github.com/acme/money.git',
      'source': 'AGENT',
      'id': 'SHA256:abc',
      'fingerprint': 'SHA256:abc',
      'forge': 'DEPLOY_KEY',
      'command': <Object>['porelo', 'credentials', 'keys', 7],
      'message': 'The push was refused.',
    });
    expect(read.outcome, 'PUSH_REFUSED');
    expect(read.address, 'ssh://git@github.com/acme/money.git');
    expect(read.source, 'AGENT');
    expect(read.id, 'SHA256:abc');
    expect(read.fingerprint, 'SHA256:abc');
    expect(read.forge, 'DEPLOY_KEY');
    expect(read.command, <String>['porelo', 'credentials', 'keys'], reason: 'a word that is no string is no argument');
    expect(read.message, 'The push was refused.');
  });

  test('an outcome added later is kept as it came, not thrown on', () {
    expect(PushRefused.from(<String, dynamic>{'outcome': 'HOST_KEY_CHANGED'}).outcome, 'HOST_KEY_CHANGED');
  });

  test('a trial is taken only where the machine says true', () {
    expect(TriedPush.from(<String, dynamic>{'accepted': true}).accepted, isTrue);
    expect(TriedPush.from(<String, dynamic>{'accepted': 'true'}).accepted, isFalse);
    expect(TriedPush.from(<String, dynamic>{}).accepted, isFalse);
  });

  test("an agent's key is told from a file's, and its public half read", () {
    final read = SshKey.from(<String, dynamic>{
      'path': '',
      'fingerprint': 'SHA256:abc',
      'found': 'AGENT',
      'publicKey': 'ssh-ed25519 AAAA alice@laptop',
    });
    expect(read.fromTheAgent, isTrue);
    expect(read.publicKey, 'ssh-ed25519 AAAA alice@laptop');
    expect(SshKey.from(<String, dynamic>{'path': '/k', 'found': 'DIRECTORY'}).fromTheAgent, isFalse);
  });
}
