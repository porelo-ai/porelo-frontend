import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_host/porelo_host.dart';
import 'package:porelo_frontend/src/app/host_stop_feed.dart';

/// The stop's terminal when the host takes its secrets from the person's file, on standard input.
void main() {
  List<String> command({
    List<String> needs = const ['vault-new', 'wireguard'],
    List<String> keys = const [],
    String email = '',
    String ssh = '/usr/bin/ssh',
    String host = 'ubuntu@203.0.113.7',
    String? driveHost = 'porelo@203.0.113.7',
  }) => hostStopFeedCommand(
    secretsFile: '/home/person/Porelo/secrets.kdbx',
    project: 'checkout',
    needs: needs,
    keys: keys,
    email: email,
    ssh: ssh,
    sshOptions: const ['-o', 'StrictHostKeyChecking=yes'],
    host: host,
    driveHost: driveHost,
  );

  // Harm: the caller's startup files or an inherited trace run beside the master password.
  test('runs a clean bash on this desktop', () {
    final run = command();
    expect(run.first, '/usr/bin/env');
    expect(run.join(' '), allOf(contains('-u BASH_ENV'), contains('-u SHELLOPTS')));
    expect(run, containsAllInOrder(<String>['/bin/bash', '--noprofile', '--norc', '-c']));
  });

  // Harm: the host is sent lines for the wrong stop, or takes them as a prompt it never asked.
  test('pipes the file\'s lines into exactly the stop the host named, on standard input', () {
    final script = command().last;
    expect(script, contains("'hosts/checkout/vault-passphrase'"));
    expect(script, contains("'hosts/checkout/wireguard'"));
    final pipe = script.substring(script.lastIndexOf('} | '));
    expect(
      pipe,
      endsWith(
        '/usr/bin/ssh -o StrictHostKeyChecking=yes -T -- ubuntu@203.0.113.7 '
        "'/usr/bin/sudo -n /usr/local/bin/porelo-host-stop --stdin vault-new wireguard'",
      ),
      reason: 'ssh and sudo by their paths, no login shell whose profile could read the pipe, no password asked',
    );
    expect(script, contains('set -o pipefail'), reason: 'a feed that fails fails the terminal');
    expect(script.indexOf('} | '), greaterThan(script.indexOf('read -rs')), reason: 'the lines go into the pipe');
    expect(script.indexOf('/usr/bin/stty -echo'), lessThan(script.indexOf('} | ')), reason: 'no echo for the file');
    expect(script, contains("trap '/usr/bin/stty echo"));
  });

  // Harm: an entry the file keeps from an earlier setup sent to a host whose machine.yml does not name it.
  test('sends the vault entries machine.yml names, only where the host asked for them', () {
    final script = command(needs: ['vault-new', 'keys'], keys: ['forge']).last;
    expect(script, contains("'hosts/checkout/keys/forge'"));
    expect(command(needs: ['vault'], keys: ['forge']).last, isNot(contains('keys/forge')));
  });

  // Harm: the drive's login typed into a pipe that carries the other secrets.
  test('asks the drive in its own terminal first, then feeds the rest', () {
    final script = command(needs: ['drive', 'vault'], email: 'me@example.org').last;
    final drive = script.indexOf("'drive'");
    expect(drive, greaterThan(-1));
    expect(drive, lessThan(script.indexOf('--stdin vault')));
    final login = script.split('\n').firstWhere((line) => line.contains(' -t '));
    expect(login, contains(' -t -- porelo@203.0.113.7 '), reason: 'the drive logs in as the account');
    expect(login, endsWith(' || exit \$?'), reason: 'a failed login sends nothing after it');
    expect(
      script.indexOf('/usr/bin/stty -echo'),
      greaterThan(script.indexOf(' -t ')),
      // ssh hands this terminal's modes to the far end's: with echo off there, the e-mail typed would not show.
      reason: 'echo kept for the drive\'s login',
    );
    expect(script.substring(0, script.indexOf('--stdin')), contains('me@example.org'));
    expect(script.substring(script.indexOf('--stdin')), isNot(contains('drive')));
  });

  test('refuses a need the file cannot give, and a stop with nothing for the file', () {
    expect(() => command(needs: ['forge-certificate']), throwsFormatException);
    expect(() => command(needs: ['drive'], email: 'me@example.org'), throwsFormatException);
  });

  // Harm: the secrets piped into whatever `ssh` PATH finds, or an option read where a host was meant.
  test('refuses an ssh by name, and a host or drive login that is no user at an address', () {
    expect(() => command(ssh: 'ssh'), throwsFormatException);
    for (final bad in <String>['-oProxyCommand=x', '203.0.113.7', "a@b'c", 'a@-b']) {
      expect(() => command(host: bad), throwsFormatException, reason: bad);
      expect(
        () => command(needs: ['drive', 'vault'], driveHost: bad),
        throwsFormatException,
        reason: bad,
      );
    }
  });

  // Against the real keepassxc-cli: what reaches the far end is the lines and nothing else.
  // Harm: a Tresorit login that failed, and the secrets piped after it all the same.
  test('a drive login that fails ends the terminal before the file is opened', () async {
    final home = await Directory(Platform.environment['HOME']!).createTemp('porelo-stop-feed-test-');
    addTearDown(() => home.delete(recursive: true));
    final calls = path.join(home.path, 'calls');
    final fakeSsh = await File(path.join(home.path, 'ssh')).writeAsString('#!/bin/sh\necho "\$@" >> $calls\nexit 3\n');
    await Process.run('chmod', ['700', fakeSsh.path]);
    final run = command(needs: ['drive', 'vault'], email: 'me@example.org', ssh: fakeSsh.path);
    final process = await Process.start(run.first, run.skip(1).toList());
    await process.stdin.close();
    await process.stdout.drain<void>();
    await process.stderr.drain<void>();
    expect(await process.exitCode, 3, reason: 'the login\'s own exit');
    expect(await File(calls).readAsLines(), hasLength(1), reason: 'no second ssh, no pipe');
  }, skip: Platform.isWindows ? 'the feed runs bash, which only Linux has here' : null);

  group('run', () {
    final cli = Platform.environment['KEEPASSXC_CLI'] ?? SecretsFile.keepassxcCli;
    final skip = File(cli).existsSync() ? null : 'needs keepassxc-cli at $cli (set KEEPASSXC_CLI) and wg';

    test('the stand-in host gets exactly the file\'s lines on its standard input', () async {
      final home = await Directory(Platform.environment['HOME']!).createTemp('porelo-stop-feed-test-');
      addTearDown(() => home.delete(recursive: true));
      final kdbx = path.join(home.path, 'secrets.kdbx');
      final made = await Process.start('bash', [
        '-c',
        SecretsFile(
          kdbx,
          cli: cli,
        ).prepareHost(project: 'checkout', create: true, publicKeyOut: path.join(home.path, 'k.pub')),
      ]);
      made.stdin.write('m\nm\n');
      await made.stdin.close();
      await made.stdout.drain<void>();
      await made.stderr.drain<void>();
      expect(await made.exitCode, 0);
      final received = path.join(home.path, 'received');
      final fakeSsh = await File(path.join(home.path, 'ssh')).writeAsString('#!/bin/sh\ncat > $received\n');
      await Process.run('chmod', ['700', fakeSsh.path]);

      final run = hostStopFeedCommand(
        secretsFile: kdbx,
        project: 'checkout',
        needs: ['vault-new', 'wireguard'],
        ssh: fakeSsh.path,
        sshOptions: const [],
        host: 'ubuntu@203.0.113.7',
        cli: cli,
      );
      final process = await Process.start(run.first, run.skip(1).toList());
      process.stdin.write('m\n');
      await process.stdin.close();
      final shown =
          '${await process.stdout.transform(utf8.decoder).join()}${await process.stderr.transform(utf8.decoder).join()}';

      expect(await process.exitCode, 0, reason: shown);
      final lines = (await File(received).readAsString()).trim().split('\n');
      expect(lines.map((line) => line.split(' ').first), ['vault-new', 'wireguard']);
      final key = utf8.decode(base64Decode(lines.last.split(' ').last));
      expect(await HostFiles.publicKey(key), (await File(path.join(home.path, 'k.pub')).readAsString()).trim());
      expect(shown, isNot(contains(key)), reason: 'nothing of it on this desktop\'s terminal');
    }, skip: skip);
  });
}
