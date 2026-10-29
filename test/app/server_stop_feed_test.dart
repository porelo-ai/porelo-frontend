import 'package:flutter_test/flutter_test.dart';

import 'package:porelo_frontend/src/app/host_stop_feed.dart';

void main() {
  // Harm: a root stop must not receive project or account secrets.
  test('a server-only stop feeds exactly its key and certificate', () {
    final command = hostStopFeedCommand(
      secretsFile: '/tmp/secrets.kdbx',
      project: 'checkout',
      secretsHost: 'orchard',
      networkNumber: 7,
      needs: ['wireguard', 'forge-certificate'],
      ssh: '/usr/bin/ssh',
      sshOptions: const ['-i', '/keys/rental'],
      host: 'root@203.0.113.7',
      serverOnly: true,
    );
    expect(command.last, contains('porelo-host-stop --stdin wireguard forge-certificate'));
    expect(command.last, contains('root@203.0.113.7'));
    expect(command.last, isNot(contains('porelo talk admit')));
    expect(command.last, contains('hosts/orchard/wireguard'));
    expect(command.last, contains('hosts/orchard/forge-ca-key'));
    expect(command.last, contains('permitted;DNS:orchard.porelo.internal,permitted;IP:10.73.7.0/255.255.255.0'));
    expect(command.last, contains('DNS:forge.orchard.porelo.internal,IP:10.73.7.1'));
    expect(command.last, contains('DNS:matrix.orchard.porelo.internal,IP:10.73.7.1'));
  });
  for (final need in ['drive', 'vault', 'vault-new', 'keys', 'matrix-token', 'unknown']) {
    test('a server-only feed refuses $need before building a terminal', () {
      expect(
        () => hostStopFeedCommand(
          secretsFile: '/tmp/secrets.kdbx',
          project: 'orchard',
          needs: ['wireguard', need],
          ssh: '/usr/bin/ssh',
          sshOptions: const [],
          host: 'root@203.0.113.7',
          serverOnly: true,
        ),
        throwsFormatException,
      );
    });
  }
}
