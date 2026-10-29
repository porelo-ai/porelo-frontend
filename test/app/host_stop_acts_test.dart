import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_host/porelo_host.dart';
import 'package:porelo_frontend/src/app/host_stop_feed.dart';

void main() {
  List<String> command(HostAct act, List<String> needs, {String? host, List<String> sshOptions = const []}) =>
      hostStopFeedCommand(
        secretsFile: '/tmp/secrets.kdbx',
        project: 'checkout',
        secretsHost: 'orchard',
        needs: needs,
        keys: const ['forge'],
        ssh: '/usr/bin/ssh',
        sshOptions: sshOptions,
        host: host ?? (act == HostAct.root ? 'root@203.0.113.7' : 'developer@203.0.113.7'),
        act: act,
      );

  // Harm: a person's project secrets are sent to root's stop.
  test('the own-account stop refuses a root login before composing a feed', () {
    expect(() => command(HostAct.ownAccount, ['vault', 'keys'], host: 'root@203.0.113.7'), throwsFormatException);
  });

  // Harm: SSH options override the checked login and send project secrets to root.
  for (final options in [
    ['-l', 'root'],
    ['-lroot'],
    ['-o', 'User=root'],
    ['-oUser=root'],
    ['-o', 'uSeR = root'],
    ['-ouSeR=root'],
    ['-o', 'USER root'],
    ['-l', 'developer'],
    ['-o', 'User=developer'],
    ['-Tl', 'root'],
    ['-To', 'User=root'],
    ['-o', '"User" root'],
    ['-i', '-o', '-l', 'root'],
    ['--', 'root@203.0.113.7'],
    ['root@203.0.113.7'],
    ['-F', '/tmp/config'],
    ['-o', 'ProxyCommand=false'],
    ['-i'],
    ['-i', 'relative-key'],
    ['-o', 'UserKnownHostsFile="/tmp/known" User=root'],
    ['-oUserKnownHostsFile="/tmp/known"'],
    ['-o', 'batchmode=yes'],
  ]) {
    test('the own-account stop refuses login override ${options.join(' ')}', () {
      expect(
        () => command(HostAct.ownAccount, ['vault'], sshOptions: options),
        throwsA(isA<FormatException>().having((error) => error.message, 'refused option', contains(options.first))),
      );
    });
  }

  // Harm: rejecting the program's pinned options prevents the account from completing setup.
  test('the own-account stop accepts the pinned option pairs the app builds', () {
    final options = pinnedHostSshOptions('/tmp/host keys/known_hosts', '/tmp/login keys/identity');
    final script = command(HostAct.ownAccount, ['vault'], sshOptions: options).last;
    expect(script, contains('developer@203.0.113.7'));
    expect(script, contains('UserKnownHostsFile="/tmp/host keys/known_hosts"'));
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
