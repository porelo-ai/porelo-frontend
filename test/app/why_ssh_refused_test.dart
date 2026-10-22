import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/tunnel.dart';

/// A refused login says what to change, from ssh's own words.
void main() {
  test('an agent cut off before its right key is told to name the key for the host', () {
    expect(
      whySshRefused('Received disconnect from 192.0.2.10 port 22:2: Too many authentication failures', 'somebody@vm'),
      allOf(contains('IdentitiesOnly yes'), contains('somebody@vm')),
    );
  });

  test('no key accepted is said as the account lacking the key, or the account', () {
    expect(whySshRefused('somebody@vm: Permission denied (publickey).', 'somebody@vm'), contains('authorized_keys'));
  });

  test('words that tell nothing say nothing', () {
    expect(whySshRefused('', 'somebody@vm'), isNull);
  });

  test('the key ssh would use is named where ssh -G lists one beyond its defaults', () {
    expect(
      keySshWouldUse(
        'hostname 203.0.113.10\n'
            'identityfile ~/.ssh/porelo-build-agent\n'
            'identityfile ~/.ssh/id_ed25519\n',
        'porelo-build',
      ),
      "It would log in with ~/.ssh/porelo-build-agent; "
      "that key's public half must be in the account's authorized_keys.",
    );
  });

  test('only default ssh identity files are said to name no key for the host', () {
    expect(
      keySshWouldUse(
        'identityfile ~/.ssh/id_rsa\n'
            'identityfile ~/.ssh/id_ecdsa\n'
            'identityfile ~/.ssh/id_ecdsa_sk\n'
            'identityfile ~/.ssh/id_ed25519\n'
            'identityfile ~/.ssh/id_ed25519_sk\n',
        'somebody@vm',
      ),
      'No key is named for somebody@vm in ~/.ssh/config.',
    );
  });
}
