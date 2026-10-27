import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_host/porelo_host.dart';
import 'package:porelo_frontend/src/app/host_stop_feed.dart';

/// The stop's terminal when the host takes its secrets from the person's file, on standard input.
void main() {
  List<String> command({List<String> needs = const ['vault-new', 'wireguard'], String email = ''}) =>
      hostStopFeedCommand(
        secretsFile: '/home/person/Porelo/secrets.kdbx',
        project: 'checkout',
        needs: needs,
        email: email,
        ssh: '/usr/bin/ssh',
        sshOptions: const ['-o', 'StrictHostKeyChecking=yes'],
        host: 'porelo@203.0.113.7',
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
    expect(script, contains('sudo /usr/local/bin/porelo-host-stop --stdin vault-new wireguard'));
    expect(script, contains('set -o pipefail'), reason: 'a feed that fails fails the terminal');
    expect(script.indexOf('} | '), greaterThan(script.indexOf('read -rs')), reason: 'the lines go into the pipe');
    expect(script, contains(" -T "), reason: 'no terminal on the far end, whose input is the pipe');
  });

  // Harm: the drive's login typed into a pipe that carries the other secrets.
  test('asks the drive in its own terminal first, then feeds the rest', () {
    final script = command(needs: ['drive', 'vault'], email: 'me@example.org').last;
    final drive = script.indexOf("'drive'");
    expect(drive, greaterThan(-1));
    expect(drive, lessThan(script.indexOf('--stdin vault')));
    expect(script.substring(0, script.indexOf('--stdin')), contains('me@example.org'));
    expect(script.substring(script.indexOf('--stdin')), isNot(contains('drive')));
  });

  test('refuses a need the file cannot give, and a stop with nothing for the file', () {
    expect(() => command(needs: ['forge-certificate']), throwsFormatException);
    expect(() => command(needs: ['drive'], email: 'me@example.org'), throwsFormatException);
  });

  // Against the real keepassxc-cli: what reaches the far end is the lines and nothing else.
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
        host: 'porelo@203.0.113.7',
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
