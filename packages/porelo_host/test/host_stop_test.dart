// Linux only: the CLI rejection guard runs the host command as a Dart subprocess.
@Tags(<String>['linux'])
library;

import 'dart:io';

import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

const init = "'/usr/local/bin/porelo-host-stop' 'vault-new'";
const loginInit = "'/usr/local/bin/porelo-host-stop' '--email' 'me@example.org' 'drive' 'vault-new'";

void main() {
  // Harm: an unreviewed command or secret argument runs on the host instead of its requested setup steps.
  test('the stop script receives only known needs and a checked email as quoted arguments', () {
    final cases = <List<String>, String>{
      ['drive']: "'/usr/local/bin/porelo-host-stop' '--email' 'me+host@example.org' 'drive'",
      ['vault']: "'/usr/local/bin/porelo-host-stop' 'vault'",
      ['vault-new']: "'/usr/local/bin/porelo-host-stop' 'vault-new'",
      ['drive', 'vault']: "'/usr/local/bin/porelo-host-stop' '--email' 'me+host@example.org' 'drive' 'vault'",
      ['drive', 'vault-new']: "'/usr/local/bin/porelo-host-stop' '--email' 'me+host@example.org' 'drive' 'vault-new'",
    };
    for (final entry in cases.entries) {
      expect(
        hostStopCommand(entry.key, email: 'me+host@example.org'),
        entry.value,
        reason: 'the host script receives exactly the public arguments it requested',
      );
    }
    for (final needs in <List<String>>[
      [],
      ['unknown'],
      ['drive', 'vault', 'sentinel-secret'],
      ['vault; id'],
    ]) {
      expect(() => hostStopCommand(needs, email: 'me@example.org'), throwsFormatException);
    }
    expect(() => hostStopCommand(['drive'], email: 'sentinel-secret'), throwsFormatException);
    expect(
      hostStopCommand(['vault'], email: 'sentinel-secret'),
      "'/usr/local/bin/porelo-host-stop' 'vault'",
      reason: 'an email is never forwarded for a vault-only stop',
    );
  });
  final commands = <List<String>, String>{
    ['drive']: "'/usr/local/bin/porelo-host-stop' '--email' 'me@example.org' 'drive'",
    ['vault-new']: init,
    ['vault']: "'/usr/local/bin/porelo-host-stop' 'vault'",
    ['drive', 'vault-new']: loginInit,
    ['drive', 'vault']: "'/usr/local/bin/porelo-host-stop' '--email' 'me@example.org' 'drive' 'vault'",
  };
  // Harm: shell syntax in an e-mail executes an unintended command on the host.
  test('an unsafe or malformed e-mail cannot become a host command', () {
    for (final email in [
      "me'@example.org",
      r'me$(id)@example.org',
      'me;@example.org',
      'me @example.org',
      '-me@example.org',
      'me@example.org\n',
      '',
      'no-address',
      'me`id`@example.org',
      'me|id@example.org',
      'me&@example.org',
      'me\\@example.org',
    ]) {
      expect(isHostDriveEmail(email), isFalse, reason: email);
      expect(() => hostStopCommand(['drive'], email: email), throwsFormatException, reason: email);
    }
    expect(isHostDriveEmail('me+host@example.org'), isTrue);
  });
  // Harm: a secret reaches automation or a command runs beyond the steps the host requested.
  for (final entry in commands.entries) {
    test('the host command for ${entry.key} is exactly the requested prompts', () {
      expect(hostStopCommand(entry.key, email: 'me@example.org'), entry.value);
    });
  }

  late Directory scratch;
  setUpAll(() async {
    scratch = await Directory.systemTemp.createTemp('host-stop-');
  });
  tearDownAll(() => scratch.delete(recursive: true));

  // Harm: the retired option reintroduces secrets into provisioning stdin.
  test('the CLI rejects answers-on-stdin even before a valued option', () async {
    for (final arguments in [
      ['up', '--answers-on-stdin'],
      ['up', '--answers-on-stdin', 'anything'],
      ['up', '--unknown', 'anything'],
    ]) {
      final result = await Process.run(
        Platform.resolvedExecutable,
        [
          'bin/porelo_host.dart',
          ...arguments,
          '--project',
          'demo',
          '--account',
          'person',
          '--public-key',
          '${scratch.path}/missing.pub',
          '--collection',
          'unused',
          '--given',
          '192.0.2.10',
          '--host-key',
          'ssh-ed25519 AAAA',
        ],
        environment: {'DASH__SUPPRESS_ANALYTICS': 'true'},
      );
      expect(result.exitCode, Exit.usage, reason: '${result.stderr}');
      expect(result.stdout, isEmpty);
    }
    // Each CLI subprocess compiles from source, which can exceed the default timeout on CI.
  }, timeout: const Timeout(Duration(minutes: 2)));
}
