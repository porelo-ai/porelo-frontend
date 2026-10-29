import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_host/porelo_host.dart';
import 'package:porelo_frontend/src/app/host_stop_feed.dart';

void main() {
  List<String> command(HostAct act, List<String> needs, {String? host}) => hostStopFeedCommand(
    secretsFile: '/tmp/secrets.kdbx',
    project: 'checkout',
    secretsHost: 'orchard',
    needs: needs,
    keys: const ['forge'],
    ssh: '/usr/bin/ssh',
    sshOptions: const [],
    host: host ?? (act == HostAct.root ? 'root@203.0.113.7' : 'developer@203.0.113.7'),
    act: act,
  );

  // Harm: a person's project secrets are sent to root's stop.
  test('the own-account stop refuses a root login before composing a feed', () {
    expect(() => command(HostAct.ownAccount, ['vault', 'keys'], host: 'root@203.0.113.7'), throwsFormatException);
  });

  // Harm: a rental's normal login cannot complete the server's privileged stop.
  test('the root stop permits the rental login and uses noninteractive sudo', () {
    final script = command(HostAct.root, ['wireguard'], host: 'developer@203.0.113.7').last;
    expect(script, contains('developer@203.0.113.7'));
    expect(script, contains('/usr/bin/sudo -n /usr/local/bin/porelo-host-stop --stdin wireguard'));
  });

  // Harm: a new secret-file capability silently crosses an existing act boundary.
  for (final act in HostAct.values) {
    test('${act.name} refuses unimplemented identities at its act boundary', () {
      expect(
        () => command(act, [act == HostAct.root ? 'wireguard' : 'vault', 'identities']),
        throwsA(
          isA<FormatException>()
              .having((error) => error.message, 'act refusal', contains(act.name))
              .having((error) => error.message, 'refused need', contains('identities')),
        ),
      );
    });
  }

  // Harm: a project secret is sent to the root stop rather than the person's vault.
  for (final need in ['keys', 'vault', 'vault-new', 'forge-central-token']) {
    test('the root stop refuses $need by name', () {
      expect(
        () => command(HostAct.root, ['wireguard', need]),
        throwsA(isA<FormatException>().having((error) => error.message, 'refused need', contains(need))),
      );
    });
  }

  // Harm: the person's vault and keys are handed to a privileged stop.
  test('the own-account feed sends its project secrets without sudo', () {
    final script = command(HostAct.ownAccount, ['vault-new', 'keys', 'forge-central-token']).last;
    expect(script, isNot(contains('sudo')));
    expect(script, contains('/usr/local/bin/porelo-host-stop --stdin vault-new keys forge-central-token'));
    expect(script, contains('developer@203.0.113.7'));
    expect(script, contains('projects/checkout/keys/forge'));
    expect(script, isNot(contains('--request')));
  });

  // Harm: a host key is disclosed to a project account, or a legacy secret is sent under the wrong act.
  for (final need in ['wireguard', 'forge-certificate', 'drive', 'matrix-token']) {
    test('the own-account stop refuses $need by name', () {
      expect(
        () => command(HostAct.ownAccount, ['vault', need]),
        throwsA(isA<FormatException>().having((error) => error.message, 'refused need', contains(need))),
      );
    });
  }
}
