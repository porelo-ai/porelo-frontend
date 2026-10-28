import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/vault_unlock.dart';

/// Which line opens or makes a machine's vault: a rented server's from the secrets file, any other's typed.
void main() {
  const server = Machine(
    name: 'checkout server',
    socketPath: '',
    kind: 'host',
    host: 'porelo@203.0.113.7',
    remoteSocket: '/run/user/1001/porelo/porelo.sock',
    hostProject: 'checkout',
  );
  const other = Machine(
    name: 'build',
    socketPath: '',
    host: 'person@198.51.100.2',
    remoteSocket: '/run/user/1000/porelo/porelo.sock',
  );

  // Harm: the person copying a passphrase this interface made and kept in the file, by hand.
  test('a rented server\'s vault opens from the secrets file, with the master password typed once', () {
    final line = unlockCommandFor(server, secretsFile: '/home/person/Porelo/secrets.kdbx')!;
    expect(line.first, '/usr/bin/env');
    expect(line.last, contains("'hosts/checkout/vault-passphrase'"));
    expect(line.last, contains("'/usr/bin/porelo vault unlock --passphrase-stdin'"));
  });

  test('without a secrets file, or for another machine, the passphrase is typed at the machine as before', () {
    expect(unlockCommandFor(server)!.last, contains('porelo vault unlock'));
    expect(unlockCommandFor(server)!.last, isNot(contains('--passphrase-stdin')));
    expect(
      unlockCommandFor(other, secretsFile: '/home/person/Porelo/secrets.kdbx')!.last,
      isNot(contains('--passphrase-stdin')),
    );
  });

  // Harm: a server's vault made with a passphrase the file never learns, which its setup then cannot open.
  test('a rented server\'s vault is never made here; another machine\'s is', () {
    expect(makeCommandFor(server), isNull);
    expect(makeCommandFor(other), isNotNull);
  });
}
