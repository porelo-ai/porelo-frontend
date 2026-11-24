// Linux: a card's ssh config path and the desktop keyring are Unix-only so far.
@Tags(['linux'])
library;

import 'dart:io';

import 'package:porelo_host/porelo_host.dart';
import 'package:porelo_host/src/secret_store_linux.dart';
import 'package:test/test.dart';

import '../bin/porelo_host.dart' as cli;

const _key = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

HostCardSsh _card() => HostCardSsh(
  name: 'alpha',
  address: 'alpha.example.org',
  sshPort: 2222,
  hostKey: _key,
  login: 'alice',
  publicKey: _key,
  webPort: 18080,
  gitPort: 18081,
  matrixPort: 18082,
);

void main() {
  late StringBuffer output;
  late StringBuffer errors;

  setUp(() {
    output = StringBuffer();
    errors = StringBuffer();
  });
  tearDown(() => hostLimits = LimitFactors.standard);

  Future<int> run(List<String> arguments) =>
      cli.runHostCommand(arguments, output: output, errors: errors, version: '1.2.3');

  group('the limits line', () {
    // Harm: a slow machine's Porelo gives longer limits, and porelo-host gives up on it as soon as on a fast one.
    test('is taken before the verb, and its factors govern the run', () async {
      expect(await run(['--limits', 'services=2.0,machines=3.0', '--version']), Exit.done);
      expect(output.toString().trim(), '1.2.3');
      expect(hostLimits, LimitFactors.parse('services=2.0,machines=3.0'));
    });

    // Harm: a run without a line inherits the factors of one before it.
    test('left out keeps the limits as they are', () async {
      hostLimits = LimitFactors.parse('machines=3.0');
      expect(await run(['--version']), Exit.done);
      expect(hostLimits, LimitFactors.standard);
      expect(hostCheckLimit, const Duration(minutes: 3));
    });

    // Harm: a line given in the wrong place is read as something else, or quietly ignored.
    test('is refused after the verb', () async {
      expect(await run(['--version', '--limits', 'machines=2.0']), Exit.usage);
      expect(
        await run(['find', '--project', 'demo', '--scaleway-project', 'p', '--limits', 'machines=2.0']),
        Exit.usage,
      );
      expect(hostLimits, LimitFactors.standard);
    });

    // Harm: a malformed line runs with limits nobody asked for, or after work has begun.
    test('is refused with a usage error when malformed, before any work', () async {
      expect(await run(['--limits', 'machines=0', '--version']), Exit.usage);
      expect(errors.toString(), contains('machines 0 lies outside 0.1 to 100'));
      expect(output.toString(), isEmpty);
      expect(await run(['--limits']), Exit.usage);
      expect(hostLimits, LimitFactors.standard);
    });
  });

  group('each limit follows its factor', () {
    setUp(() => hostLimits = LimitFactors.parse('services=2.0,machines=3.0'));

    // Harm: a check of a slow machine reads as not having answered.
    test('the host check: machines', () {
      expect(hostCheckLimit, const Duration(minutes: 9));
    });

    // Harm: the keyring prompt is given up while the desktop is still slow to put it up.
    test('the keyring prompt: services', () {
      expect(SecretServiceStore().promptWithin, const Duration(minutes: 4));
      expect(SecretServiceStore(promptWithin: const Duration(seconds: 1)).promptWithin, const Duration(seconds: 1));
    });

    // Harm: ssh gives up connecting to a slow host, and a shared host's command is ended while it still works.
    test('ssh to a host: machines', () async {
      final commands = <List<String>>[];
      final ssh = OpenSsh.sharedHost(
        card: _card(),
        config: '/config/porelo/ssh/alpha.conf',
        environment: {'XDG_CONFIG_HOME': '/config'},
        start: (executable, arguments) {
          commands.add([executable, ...arguments]);
          return Process.start('/bin/sh', ['-c', 'cat >/dev/null']);
        },
      );
      expect(ssh.deadline, const Duration(minutes: 15));
      await ssh.run('alpha', '', 'true');
      expect(commands.single, containsAllInOrder(['-o', 'ConnectTimeout=30']));
    });

    // Harm: refreshing the organization gives up connecting to a slow host.
    test('the organization refresh: machines', () {
      final arguments = organizationRefreshArguments(
        card: _card(),
        config: '/config/porelo/ssh/alpha.conf',
        environment: {'XDG_CONFIG_HOME': '/config'},
      );
      expect(arguments, containsAllInOrder(['-o', 'ConnectTimeout=30']));
    });
  });
}
