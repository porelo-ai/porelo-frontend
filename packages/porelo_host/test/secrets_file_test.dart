import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

/// The secrets file's script: what runs in the terminal so that no secret passes through the interface.
void main() {
  const file = '/home/person/Porelo/secrets.kdbx';
  const publicKeyOut = '/home/person/.local/state/porelo-frontend/host-checkout.pub';

  group('the script', () {
    // A secret in an argument is readable by every process on the desktop; in the script it is on disk.
    test('asks the master password once and hands it on only on standard input', () {
      final script = SecretsFile(file).prepareHost(project: 'checkout', create: false, publicKeyOut: publicKeyOut);
      final made = SecretsFile(file).prepareHost(project: 'checkout', create: true, publicKeyOut: publicKeyOut);

      expect(RegExp(r'read -rs').allMatches(script).length, 1, reason: 'one master password, asked once');
      expect(RegExp(r'read -rs').allMatches(made).length, 2, reason: 'a new one asked twice, to be sure of it');
      expect(script, isNot(contains('--password')), reason: 'keepassxc-cli takes no password as an argument');
      expect(script, isNot(contains('export ')), reason: 'nothing goes into the environment of another program');
      // Every use of it, with the builtin printf's and the shell's own comparison taken away, leaves none.
      for (final line in '$script\n$made'.split('\n')) {
        final rest = line
            .replaceAll(r'''printf '%s\n%s\n' "$MASTER" "$MASTER"''', '')
            .replaceAll(r'''printf '%s\n' "$MASTER"''', '')
            .replaceAll(r'''printf '%s\n%s\n' "$MASTER"''', '')
            .replaceAll(r'''[ "$MASTER" != "$AGAIN" ]''', '');
        expect(rest, isNot(contains(r'$MASTER')), reason: 'only the builtin printf sees it: $line');
      }
    });

    // The entries another desktop or a person's own file must find under the same names.
    test('names the entries below the root group by their path', () {
      final script = SecretsFile(file).prepareHost(project: 'checkout', create: true, publicKeyOut: publicKeyOut);

      expect(script, contains("'hosts/checkout/wireguard'"));
      expect(script, contains("'hosts/checkout/vault-passphrase'"));
      expect(script, contains("db-create"));
      expect(script, contains("'shared'"));
    });

    test('makes no file when one is named', () {
      final script = SecretsFile(file).prepareHost(project: 'checkout', create: false, publicKeyOut: publicKeyOut);

      expect(script, isNot(contains('db-create')), reason: 'an existing file is never made anew over');
    });

    // A path or name that reaches a shell unquoted runs whatever it holds.
    test('refuses a file, a project or an output path a shell would read as more than a word', () {
      for (final bad in <String>[
        "/home/person/a'b.kdbx",
        'relative.kdbx',
        '/home/person/a\nb.kdbx',
        '/home/x/\$(id).kdbx',
      ]) {
        expect(
          () => SecretsFile(bad).prepareHost(project: 'checkout', create: true, publicKeyOut: publicKeyOut),
          throwsFormatException,
          reason: bad,
        );
      }
      expect(
        () => SecretsFile(file).prepareHost(project: "checkout'x", create: true, publicKeyOut: publicKeyOut),
        throwsA(isA<HostFilesRefused>()),
      );
      expect(
        () => SecretsFile(file).prepareHost(project: 'checkout', create: true, publicKeyOut: "/tmp/a'b"),
        throwsFormatException,
      );
    });
  });

  // Against the real keepassxc-cli: the file made, read back, and the host's key never printed.
  group('run with keepassxc-cli', () {
    final cli = Platform.environment['KEEPASSXC_CLI'] ?? SecretsFile.keepassxcCli;
    final skip = File(cli).existsSync() && Process.runSync('which', ['wg']).exitCode == 0
        ? null
        : 'needs keepassxc-cli at $cli (set KEEPASSXC_CLI) and wg';
    // The snap's keepassxc-cli may not write in /tmp or a hidden folder, so the folder is a plain one of the home.
    late Directory home;

    setUp(() async {
      home = await Directory(Platform.environment['HOME']!).createTemp('porelo-secrets-test-');
    });

    tearDown(() async {
      if (await home.exists()) await home.delete(recursive: true);
    });

    Future<ProcessResult> run(String script, String master, {bool twice = false}) async {
      final process = await Process.start('bash', ['-c', script]);
      process.stdin.write(twice ? '$master\n$master\n' : '$master\n');
      await process.stdin.close();
      final out = await process.stdout.transform(utf8.decoder).join();
      final err = await process.stderr.transform(utf8.decoder).join();
      return ProcessResult(process.pid, await process.exitCode, out, err);
    }

    Future<String> show(String kdbx, String entry, String master) async {
      final process = await Process.start(cli, ['show', '-s', '-a', 'password', kdbx, entry]);
      process.stdin.write('$master\n');
      await process.stdin.close();
      final out = await process.stdout.transform(utf8.decoder).join();
      expect(await process.exitCode, 0, reason: 'the entry $entry is in the file');
      return out.trim();
    }

    test('makes the file, the host key and its passphrase, and writes out only the public half', () async {
      final kdbx = path.join(home.path, 'secrets.kdbx');
      final out = path.join(home.path, 'checkout.pub');
      final script = SecretsFile(kdbx, cli: cli).prepareHost(project: 'checkout', create: true, publicKeyOut: out);

      final result = await run(script, 'test-master', twice: true);

      expect(result.exitCode, 0, reason: 'the script ran: ${result.stderr}');
      final private = await show(kdbx, 'hosts/checkout/wireguard', 'test-master');
      expect(await HostFiles.publicKey(private), (await File(out).readAsString()).trim(), reason: 'its public half');
      expect('${result.stdout}${result.stderr}', isNot(contains(private)), reason: 'the key is never printed');
      expect(await show(kdbx, 'hosts/checkout/vault-passphrase', 'test-master'), isNotEmpty);
      expect((await File(out).stat()).modeString(), 'rw-------');
    }, skip: skip);

    test('keeps the key a second run finds, so the tunnel stays the same', () async {
      final kdbx = path.join(home.path, 'secrets.kdbx');
      final out = path.join(home.path, 'checkout.pub');
      final first = SecretsFile(kdbx, cli: cli).prepareHost(project: 'checkout', create: true, publicKeyOut: out);
      expect((await run(first, 'test-master', twice: true)).exitCode, 0);
      final before = await File(out).readAsString();

      final again = SecretsFile(kdbx, cli: cli).prepareHost(project: 'checkout', create: false, publicKeyOut: out);
      final result = await run(again, 'test-master');

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(await File(out).readAsString(), before, reason: 'the same host key, not a new one');
    }, skip: skip);

    test('a wrong master password writes nothing and fails', () async {
      final kdbx = path.join(home.path, 'secrets.kdbx');
      final out = path.join(home.path, 'checkout.pub');
      expect(
        (await run(
          SecretsFile(kdbx, cli: cli).prepareHost(project: 'checkout', create: true, publicKeyOut: out),
          'right',
          twice: true,
        )).exitCode,
        0,
      );
      await File(out).delete();

      final result = await run(
        SecretsFile(kdbx, cli: cli).prepareHost(project: 'other', create: false, publicKeyOut: out),
        'wrong',
      );

      expect(result.exitCode, isNot(0));
      expect(await File(out).exists(), isFalse, reason: 'no public half without the file opened');
    }, skip: skip);
  });
}
