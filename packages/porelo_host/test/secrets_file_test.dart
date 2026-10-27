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
      final script = SecretsFile(file).prepareHost(
        project: 'checkout',
        create: false,
        publicKeyOut: publicKeyOut,
        keys: {'forge': '/home/person/forge-token'},
      );
      final made = SecretsFile(file).prepareHost(project: 'checkout', create: true, publicKeyOut: publicKeyOut);
      final fed = SecretsFile(file).stopLines(project: 'checkout', needs: ['vault', 'keys'], keys: ['forge']);

      expect(RegExp(r'read -rs').allMatches(script).length, 1, reason: 'one master password, asked once');
      expect(RegExp(r'read -rs').allMatches(made).length, 2, reason: 'a new one asked twice, to be sure of it');
      expect(script, isNot(contains('--password')), reason: 'keepassxc-cli takes no password as an argument');
      for (final needle in <String>['export ', 'set -a', 'declare -x', 'env ', r'${MASTER', r'${private']) {
        expect(
          '$script\n$made',
          isNot(contains(needle)),
          reason: 'nothing goes into another program\'s environment: $needle',
        );
      }
      for (final each in <String>[script, made, fed]) {
        expect(
          each.split('\n').first,
          '/usr/bin/stty -echo 2>/dev/null || true',
          reason: 'no echo from the first byte',
        );
        expect(each, contains('\nset +x\n'), reason: 'an inherited trace never prints a secret');
        expect(each, contains("trap '/usr/bin/stty echo"), reason: 'echo comes back however the script ends');
      }
      final drives = SecretsFile(file).prepareHost(
        project: 'checkout',
        create: true,
        publicKeyOut: publicKeyOut,
        migrateKeyFrom: '/home/person/w.key',
      );
      for (final each in <String>[script, made, drives, fed]) {
        expect(each, isNot(contains('<<<')), reason: 'a here-string may be a file on an older bash');
        expect(
          RegExp(
            r"(^|[;|&('{!]\s*|\$\(|then |else |do )(wg|mkdir|dirname|tr|rm|mv|base64|stty|realpath|cat) ",
            multiLine: true,
          ).hasMatch(each),
          isFalse,
          reason: 'every tool by its absolute path',
        );
      }
      expect(
        drives.indexOf('does not hold a WireGuard key'),
        lessThan(drives.indexOf('/usr/bin/rm -f')),
        reason: 'the file is read back before the drive copy goes',
      );
      // Every use of it, with the builtin printf's and the shell's own comparison taken away, leaves none.
      for (final line in '$script\n$made\n$fed'.split('\n')) {
        final rest = line
            .replaceAll(r'''printf '%s\n%s\n' "$MASTER" "$MASTER"''', '')
            .replaceAll(r'''printf '%s\n' "$MASTER"''', '')
            .replaceAll(r'''printf '%s\n%s\n' "$MASTER"''', '')
            .replaceAll(r'''[ "$MASTER" != "$AGAIN" ]''', '')
            .replaceAll(r'''[ -z "$MASTER" ]''', '');
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

  group('the stop\'s lines', () {
    // Harm: a secret in an argument, or a line for a need the host did not ask, which it refuses after renting.
    test('reads the master password once and writes only the lines the stop named', () {
      final feed = SecretsFile(file)
          .stopLines(project: 'checkout', needs: ['vault', 'wireguard', 'keys'], keys: ['forge', 'ci.key']);

      expect(RegExp(r'read -rs').allMatches(feed).length, 1);
      expect(feed, contains("'hosts/checkout/vault-passphrase'"));
      expect(feed, contains("'hosts/checkout/wireguard'"));
      expect(feed, contains("'hosts/checkout/keys/forge'"));
      expect(feed, contains("'hosts/checkout/keys/ci.key'"));
      expect(
        feed,
        isNot(contains(' ls "\$file" \'hosts/checkout/keys\'')),
        reason: 'only the entries machine.yml names',
      );
      expect(feed, isNot(contains('db-create')), reason: 'the stop never makes a file');
      expect(
        SecretsFile(file).stopLines(project: 'checkout', needs: ['forge-central-token']),
        contains("'shared/forge-central-token'"),
        reason: 'the central forge\'s token is the person\'s, shared by every host',
      );
      expect(feed, isNot(contains('add ')), reason: 'the stop changes nothing in the file');
      // Harm: a value that fails to encode after an earlier line went, which the host could take as its whole feed.
      expect(
        feed.lastIndexOf('/usr/bin/base64'),
        lessThan(feed.indexOf("printf '%s %s\\n'")),
        reason: 'every value encoded before the first line is written',
      );
      expect(feed, contains('if [ -z "\$ev0" ] ||'), reason: 'an empty encoding is no value');
      expect(feed, contains('if [ -z "\$v2" ] ||'), reason: 'nor an empty entry');
    });

    test('refuses a need it does not know, the drive among them, before anything is read', () {
      for (final need in <String>['drive', 'forge-certificate', 'vault; rm', '']) {
        expect(
          () => SecretsFile(file).stopLines(project: 'checkout', needs: [need]),
          throwsFormatException,
          reason: need,
        );
      }
      expect(() => SecretsFile(file).stopLines(project: "a'b", needs: ['keys']), throwsA(isA<HostFilesRefused>()));
      expect(() => SecretsFile(file).stopLines(project: 'checkout', needs: []), throwsFormatException);
      expect(
        () => SecretsFile(file).stopLines(project: 'checkout', needs: ['vault', 'vault-new']),
        throwsFormatException,
        reason: 'a new vault and an open one are never asked at once',
      );
      expect(
        () => SecretsFile(file).stopLines(project: 'checkout', needs: ['vault'], keys: ['forge']),
        throwsFormatException,
        reason: 'no key line where the host did not ask for its entries',
      );
      for (final name in <String>['_x', 'a b', "a'b", 'a/b', '']) {
        expect(
          () => SecretsFile(file).stopLines(project: 'checkout', needs: ['keys'], keys: [name]),
          throwsA(isA<HostFilesRefused>()),
          reason: name,
        );
      }
      expect(
        () => SecretsFile(file).stopLines(project: 'checkout', needs: ['keys'], keys: ['forge', 'forge']),
        throwsFormatException,
      );
      // Harm: a stop for a missing entry answered with no line, and `up` refusing the same way again.
      expect(
        () => SecretsFile(file).stopLines(project: 'checkout', needs: ['keys']),
        throwsFormatException,
        reason: 'only beside a new vault may the entries be none',
      );
      expect(SecretsFile(file).stopLines(project: 'checkout', needs: ['vault-new', 'keys']), isNotEmpty);
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

    Future<void> cliIn(String kdbx, List<String> arguments, String master, {String? then}) async {
      final process = await Process.start(cli, arguments);
      process.stdin.write(then == null ? '$master\n' : '$master\n$then\n');
      await process.stdin.close();
      await process.stdout.drain<void>();
      await process.stderr.drain<void>();
      expect(await process.exitCode, 0, reason: '${arguments.first} in the file');
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

    // Harm: a key left in the clear on the drive beside the file, or the file's key silently replaced by another.
    test('a drive key beside the file is removed when it is the same, and refused when it differs', () async {
      final kdbx = path.join(home.path, 'secrets.kdbx');
      final out = path.join(home.path, 'checkout.pub');
      final drive = File(path.join(home.path, 'wireguard.key'));
      final made = SecretsFile(kdbx, cli: cli).prepareHost(project: 'checkout', create: true, publicKeyOut: out);
      expect((await run(made, 'm', twice: true)).exitCode, 0);
      final kept = await show(kdbx, 'hosts/checkout/wireguard', 'm');

      await drive.writeAsString('$kept\n');
      final same = SecretsFile(
        kdbx,
        cli: cli,
      ).prepareHost(project: 'checkout', create: false, publicKeyOut: out, migrateKeyFrom: drive.path);
      expect((await run(same, 'm')).exitCode, 0);
      expect(await drive.exists(), isFalse, reason: 'the copy on the drive goes once the file holds the same key');

      await drive.writeAsString('${base64Encode(List<int>.filled(32, 3))}\n');
      final other = await run(same, 'm');
      expect(other.exitCode, isNot(0), reason: 'two different keys for one host are never merged silently');
      expect(await drive.exists(), isTrue, reason: 'nothing is removed when they differ');
      expect(await show(kdbx, 'hosts/checkout/wireguard', 'm'), kept, reason: 'the file keeps its own key');
    }, skip: skip);

    // Harm: the host's key left in the clear on the drive, or lost when what lay there was no key.
    test(
      'a valid drive key moves into the file and leaves the drive; a broken one or a link is refused and kept',
      () async {
        final kdbx = path.join(home.path, 'secrets.kdbx');
        final out = path.join(home.path, 'checkout.pub');
        final drive = File(path.join(home.path, 'wireguard.key'));
        final original = base64Encode(List<int>.filled(32, 7));

        await drive.writeAsString('not a key\n');
        final broken = await run(
          SecretsFile(
            kdbx,
            cli: cli,
          ).prepareHost(project: 'checkout', create: true, publicKeyOut: out, migrateKeyFrom: drive.path),
          'm',
          twice: true,
        );
        expect(broken.exitCode, isNot(0), reason: 'a drive file that is no key is refused');
        expect(await drive.readAsString(), 'not a key\n', reason: 'and kept as it was');
        expect(await File(kdbx).exists(), isFalse, reason: 'and no file made before the refusal');

        await drive.writeAsString('$original\n');
        final moved = await run(
          SecretsFile(
            kdbx,
            cli: cli,
          ).prepareHost(project: 'checkout', create: true, publicKeyOut: out, migrateKeyFrom: drive.path),
          'm',
          twice: true,
        );
        expect(moved.exitCode, 0, reason: '${moved.stderr}');
        expect(await show(kdbx, 'hosts/checkout/wireguard', 'm'), original, reason: 'the drive key is the file\'s now');
        expect(await drive.exists(), isFalse, reason: 'and gone from the drive');
        expect((await File(out).readAsString()).trim(), await HostFiles.publicKey(original));

        final target = await File(path.join(home.path, 'elsewhere')).writeAsString('$original\n');
        await Link(drive.path).create(target.path);
        final linked = await run(
          SecretsFile(
            kdbx,
            cli: cli,
          ).prepareHost(project: 'checkout', create: false, publicKeyOut: out, migrateKeyFrom: drive.path),
          'm',
        );
        expect(linked.exitCode, isNot(0), reason: 'a link on the drive is outside input and refused');
        expect(await target.exists(), isTrue);
        expect(FileSystemEntity.typeSync(drive.path, followLinks: false), FileSystemEntityType.link, reason: 'kept');

        await Link(drive.path).delete();
        await Directory(drive.path).create();
        final folder = await run(
          SecretsFile(
            kdbx,
            cli: cli,
          ).prepareHost(project: 'checkout', create: false, publicKeyOut: out, migrateKeyFrom: drive.path),
          'm',
        );
        expect(folder.exitCode, isNot(0), reason: 'a folder where the key was is refused, never passed over');
      },
      skip: skip,
    );

    // Harm: a vault entry's file copied to the drive in the clear, or replaced by another without a word.
    test('a vault entry\'s file goes into the file base64, and a link or a missing file is refused', () async {
      final kdbx = path.join(home.path, 'secrets.kdbx');
      final out = path.join(home.path, 'checkout.pub');
      final chosen = await File(path.join(home.path, 'forge-token')).writeAsBytes([1, 2, 3, 250]);

      final made = await run(
        SecretsFile(
          kdbx,
          cli: cli,
        ).prepareHost(project: 'checkout', create: true, publicKeyOut: out, keys: {'forge': chosen.path}),
        'm',
        twice: true,
      );
      expect(made.exitCode, 0, reason: '${made.stderr}');
      expect(await show(kdbx, 'hosts/checkout/keys/forge', 'm'), base64Encode([1, 2, 3, 250]));
      expect(await chosen.exists(), isTrue, reason: 'the person\'s own file stays theirs');

      final link = path.join(home.path, 'link-token');
      await Link(link).create(chosen.path);
      final linked = await run(
        SecretsFile(
          kdbx,
          cli: cli,
        ).prepareHost(project: 'checkout', create: false, publicKeyOut: out, keys: {'other': link}),
        'm',
      );
      expect(linked.exitCode, isNot(0), reason: 'a link is refused');
      final gone = await run(
        SecretsFile(kdbx, cli: cli).prepareHost(
          project: 'checkout',
          create: false,
          publicKeyOut: out,
          keys: {'other': path.join(home.path, 'nothing')},
        ),
        'm',
      );
      expect(gone.exitCode, isNot(0), reason: 'a file that is not there is refused');

      final empty = await File(path.join(home.path, 'empty')).create();
      final none = await run(
        SecretsFile(
          kdbx,
          cli: cli,
        ).prepareHost(project: 'checkout', create: false, publicKeyOut: out, keys: {'other': empty.path}),
        'm',
      );
      expect(none.exitCode, isNot(0), reason: 'an empty file would be an entry the stop cannot send');

      final real = await Directory(path.join(home.path, 'real')).create();
      await File(path.join(real.path, 'token')).writeAsBytes([4]);
      await Link(path.join(home.path, 'via')).create(real.path);
      final through = await run(
        SecretsFile(kdbx, cli: cli).prepareHost(
          project: 'checkout',
          create: false,
          publicKeyOut: out,
          keys: {'other': path.join(home.path, 'via', 'token')},
        ),
        'm',
      );
      expect(through.exitCode, isNot(0), reason: 'a folder on the way that is a link is refused too');
      expect(
        Process.runSync(cli, ['show', kdbx, 'hosts/checkout/keys/other']).exitCode,
        isNot(0),
        reason: 'none of these kept anything',
      );
    }, skip: skip);

    // Harm: a key the file keeps that is none, used or added over after other entries were changed.
    test('a kept host key that is no key, or an empty one, changes nothing', () async {
      final kdbx = path.join(home.path, 'secrets.kdbx');
      final out = path.join(home.path, 'checkout.pub');
      final chosen = await File(path.join(home.path, 'token')).writeAsBytes([5]);
      expect(
        (await run(
          SecretsFile(kdbx, cli: cli).prepareHost(project: 'first', create: true, publicKeyOut: out),
          'm',
          twice: true,
        )).exitCode,
        0,
      );
      await cliIn(kdbx, ['mkdir', kdbx, 'hosts/checkout'], 'm');
      for (final (project, value) in [('checkout', 'not a key'), ('other', '')]) {
        if (project == 'other') await cliIn(kdbx, ['mkdir', kdbx, 'hosts/other'], 'm');
        await cliIn(kdbx, ['add', '-p', kdbx, 'hosts/$project/wireguard'], 'm', then: value);
        final refused = await run(
          SecretsFile(
            kdbx,
            cli: cli,
          ).prepareHost(project: project, create: false, publicKeyOut: out, keys: {'forge': chosen.path}),
          'm',
        );
        expect(refused.exitCode, isNot(0), reason: project);
        expect(
          '${refused.stderr}',
          contains(value.isEmpty ? 'has an empty hosts/other/wireguard' : 'keeps no WireGuard key'),
          reason: 'what to mend is named',
        );
        for (final entry in ['hosts/$project/vault-passphrase', 'hosts/$project/keys/forge']) {
          expect(
            Process.runSync('bash', ['-c', 'printf "m\\n" | $cli show "$kdbx" $entry']).exitCode,
            isNot(0),
            reason: '$entry not added before the refusal',
          );
        }
      }
    }, skip: skip);

    // Harm: the drive's key removed, or the file changed, by a run that then refuses.
    test('another file for a kept vault entry changes nothing, and the same one is taken as it is', () async {
      final kdbx = path.join(home.path, 'secrets.kdbx');
      final out = path.join(home.path, 'checkout.pub');
      final drive = File(path.join(home.path, 'wireguard.key'));
      final first = await File(path.join(home.path, 'first')).writeAsBytes([1, 2, 3]);
      final second = await File(path.join(home.path, 'second')).writeAsBytes([7, 7, 7]);
      expect(
        (await run(
          SecretsFile(
            kdbx,
            cli: cli,
          ).prepareHost(project: 'checkout', create: true, publicKeyOut: out, keys: {'forge': first.path}),
          'm',
          twice: true,
        )).exitCode,
        0,
      );
      final kept = await show(kdbx, 'hosts/checkout/wireguard', 'm');
      await drive.writeAsString('$kept\n');

      final other = await run(
        SecretsFile(kdbx, cli: cli).prepareHost(
          project: 'checkout',
          create: false,
          publicKeyOut: out,
          migrateKeyFrom: drive.path,
          // The new entry first: a check made in the adding loop would have added it before refusing.
          keys: {'ci': second.path, 'forge': second.path},
        ),
        'm',
      );
      expect(other.exitCode, isNot(0));
      expect('${other.stderr}', contains('keeps another forge'));
      expect(await drive.exists(), isTrue, reason: 'the drive\'s key stays where a refusal follows');
      expect(await show(kdbx, 'hosts/checkout/keys/forge', 'm'), base64Encode([1, 2, 3]));
      expect(
        Process.runSync('bash', ['-c', 'printf "m\\n" | $cli show "$kdbx" hosts/checkout/keys/ci']).exitCode,
        isNot(0),
        reason: 'nothing added before the refusal',
      );

      final same = await run(
        SecretsFile(kdbx, cli: cli).prepareHost(
          project: 'checkout',
          create: false,
          publicKeyOut: out,
          migrateKeyFrom: drive.path,
          keys: {'forge': first.path},
        ),
        'm',
      );
      expect(same.exitCode, 0, reason: '${same.stderr}');
      expect(await drive.exists(), isFalse);
    }, skip: skip);

    test('an empty master password makes no file', () async {
      final kdbx = path.join(home.path, 'secrets.kdbx');
      final out = path.join(home.path, 'checkout.pub');
      final result = await run(
        SecretsFile(kdbx, cli: cli).prepareHost(project: 'checkout', create: true, publicKeyOut: out),
        '',
        twice: true,
      );
      expect(result.exitCode, isNot(0));
      expect(await File(kdbx).exists(), isFalse);
    }, skip: skip);

    // Harm: a host given the wrong secret, or a missing one, which the stop refuses only after the person typed.
    test('the stop\'s lines carry each entry base64, in the agreed form, and a missing entry gives none', () async {
      final kdbx = path.join(home.path, 'secrets.kdbx');
      final out = path.join(home.path, 'checkout.pub');
      expect(
        (await run(
          SecretsFile(kdbx, cli: cli).prepareHost(project: 'checkout', create: true, publicKeyOut: out),
          'm',
          twice: true,
        )).exitCode,
        0,
      );
      final key = await show(kdbx, 'hosts/checkout/wireguard', 'm');
      final passphrase = await show(kdbx, 'hosts/checkout/vault-passphrase', 'm');

      final fed = await run(
        SecretsFile(kdbx, cli: cli).stopLines(project: 'checkout', needs: ['vault-new', 'wireguard']),
        'm',
      );

      expect(fed.exitCode, 0, reason: '${fed.stderr}');
      expect('${fed.stdout}'.trim().split('\n'), <String>[
        'vault-new ${base64Encode(utf8.encode(passphrase))}',
        'wireguard ${base64Encode(utf8.encode(key))}',
      ]);
      expect('${fed.stderr}', isNot(contains(key)), reason: 'nothing of it on the terminal');

      // A machine without vault entries: no key line at all, as the stop takes `keys` beside `vault-new`.
      final none = await run(
        SecretsFile(kdbx, cli: cli).stopLines(project: 'checkout', needs: ['vault-new', 'keys']),
        'm',
      );
      expect(none.exitCode, 0, reason: '${none.stderr}');
      expect('${none.stdout}'.trim().split('\n'), hasLength(1), reason: 'the passphrase alone');

      final missing = await run(SecretsFile(kdbx, cli: cli).stopLines(project: 'other', needs: ['vault']), 'm');
      expect(missing.exitCode, isNot(0));
      expect('${missing.stdout}', isEmpty, reason: 'no line at all when an entry is missing');

      // The vault entries' files, kept base64 in the group, go out as they are, one line each.
      await cliIn(kdbx, ['mkdir', kdbx, 'hosts/checkout/keys'], 'm');
      await cliIn(
        kdbx,
        ['add', '-p', kdbx, 'hosts/checkout/keys/forge'],
        'm',
        then: base64Encode(utf8.encode('token-bytes')),
      );
      await cliIn(kdbx, ['add', '-p', kdbx, 'hosts/checkout/keys/ci.key'], 'm', then: base64Encode([0, 1, 2, 255]));
      // An entry kept from an earlier setup that machine.yml no longer names.
      await cliIn(kdbx, ['add', '-p', kdbx, 'hosts/checkout/keys/legacy'], 'm', then: base64Encode([9]));
      final keys = await run(
        SecretsFile(kdbx, cli: cli).stopLines(project: 'checkout', needs: ['vault', 'keys'], keys: ['forge', 'ci.key']),
        'm',
      );
      expect(keys.exitCode, 0, reason: '${keys.stderr}');
      expect('${keys.stdout}'.trim().split('\n').skip(1).toList(), <String>[
        'key forge ${base64Encode(utf8.encode('token-bytes'))}',
        'key ci.key ${base64Encode([0, 1, 2, 255])}',
      ], reason: 'the entries machine.yml names, and no other');

      // A value kept by hand that is no whole base64 sends nothing.
      for (final (name, value) in [('plain', 'token'), ('short', 'a'), ('cut', 'ab=')]) {
        await cliIn(kdbx, ['add', '-p', kdbx, 'hosts/checkout/keys/$name'], 'm', then: value);
        final refused = await run(
          SecretsFile(kdbx, cli: cli).stopLines(project: 'checkout', needs: ['vault', 'keys'], keys: ['forge', name]),
          'm',
        );
        expect(refused.exitCode, isNot(0), reason: value);
        expect('${refused.stdout}', isEmpty, reason: 'no line at all for $value');
        expect('${refused.stderr}', contains('hosts/checkout/keys/$name is not base64'));
      }
      expect('${missing.stderr}', contains('hosts/other/vault-passphrase'), reason: 'what is missing is named');
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
