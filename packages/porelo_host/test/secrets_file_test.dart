import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as path;
import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

/// The secrets file's script: what runs in the terminal so that no secret passes through the interface.
void main() {
  // Harm: a terminal opened on a keepassxc-cli that is not there, which ends with 127 and says nothing a person reads.
  test('a missing keepassxc-cli is said with how it is installed, before any terminal opens', () {
    expect(
      SecretsFile.missingCli('/nonexistent/keepassxc-cli'),
      allOf(contains('keepassxc-cli'), contains('sudo apt install keepassxc-minimal')),
    );
    expect(SecretsFile.missingCli(Platform.resolvedExecutable), isNull, reason: 'one that is there is said nothing of');
  });

  const file = '/home/person/Porelo/secrets.kdbx';
  const publicKeyOut = '/home/person/.local/state/porelo-frontend/host-checkout.pub';

  // Invalid host names must never select another group or inject commands into a terminal.
  test('refuses unsafe host entry names before building an entry path', () {
    for (final host in ['', '-first', 'a/b', 'a\nb', 'a;id', '..', '.hidden']) {
      for (final build in <void Function()>[
        () => SecretsFile.hostKey(host),
        () => SecretsFile.forgeCaKey(host),
        () => SecretsFile.forgeCa(host),
        () => SecretsFile.forgeName(host),
        () => SecretsFile(file).prepareHost(host: host, project: 'checkout', create: true, publicKeyOut: publicKeyOut),
        () => SecretsFile(file).stopLines(host: host, project: 'checkout', needs: ['vault']),
      ]) {
        expect(build, throwsA(isA<HostFilesRefused>()), reason: host);
      }
    }
    for (final host in ['a', '0', 'rented-box', 'UPPER', 'under_score', 'with.dot', 'last-', 'a' * 64]) {
      expect(SecretsFile.hostKey(host), 'hosts/$host/wireguard');
    }
  });

  // Harm: an unchecked network signs certificates for another subnet or injects an extension value.
  test('only network octets are accepted for certificate scripts and addresses', () {
    for (final number in [-1, 256, 1000]) {
      expect(() => SecretsFile.forgeAddress(number), throwsFormatException);
      expect(
        () =>
            SecretsFile(file)
                .stopLines(host: 'checkout', project: 'checkout', needs: ['forge-certificate'], networkNumber: number),
        throwsFormatException,
      );
    }
    expect(SecretsFile.forgeAddress(0), '10.73.0.1');
    expect(SecretsFile.forgeAddress(255), '10.73.255.1');
    expect(SecretsFile.forgeName('checkout'), 'forge.checkout.porelo.internal');
  });

  group('the script', () {
    // A secret in an argument is readable by every process on the desktop; in the script it is on disk.
    test('asks the master password once and hands it on only on standard input', () {
      final script = SecretsFile(file).prepareHost(
        host: 'checkout',
        project: 'checkout',
        create: false,
        publicKeyOut: publicKeyOut,
        keys: {'forge': '/home/person/forge-token'},
      );
      final made = SecretsFile(file)
          .prepareHost(host: 'checkout', project: 'checkout', create: true, publicKeyOut: publicKeyOut);
      final fed = SecretsFile(file)
          .stopLines(host: 'checkout', project: 'checkout', needs: ['vault', 'keys'], keys: ['forge']);

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
        host: 'checkout',
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

    test('makes no file when one is named', () {
      final script = SecretsFile(file)
          .prepareHost(host: 'checkout', project: 'checkout', create: false, publicKeyOut: publicKeyOut);

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
          () =>
              SecretsFile(bad)
                  .prepareHost(host: 'checkout', project: 'checkout', create: true, publicKeyOut: publicKeyOut),
          throwsFormatException,
          reason: bad,
        );
      }
      expect(
        () =>
            SecretsFile(file)
                .prepareHost(host: "checkout'x", project: "checkout'x", create: true, publicKeyOut: publicKeyOut),
        throwsA(isA<HostFilesRefused>()),
      );
      expect(
        () =>
            SecretsFile(file)
                .prepareHost(host: 'checkout', project: 'checkout', create: true, publicKeyOut: "/tmp/a'b"),
        throwsFormatException,
      );
    });
  });

  group('the stop\'s lines', () {
    // Harm: a secret in an argument, or a line for a need the host did not ask, which it refuses after renting.
    test('reads the master password once and writes only the lines the stop named', () {
      final feed = SecretsFile(file).stopLines(
        host: 'checkout',
        project: 'checkout',
        needs: ['vault', 'wireguard', 'keys'],
        keys: ['forge', 'ci.key'],
      );

      expect(RegExp(r'read -rs').allMatches(feed).length, 1);
      expect(feed, contains("'projects/checkout/vault-passphrase'"));
      expect(feed, contains("'hosts/checkout/wireguard'"));
      expect(feed, contains("'projects/checkout/keys/forge'"));
      expect(feed, contains("'projects/checkout/keys/ci.key'"));
      expect(feed, isNot(contains('db-create')), reason: 'the stop never makes a file');
      expect(
        SecretsFile(file).stopLines(host: 'checkout', project: 'checkout', needs: ['forge-central-token']),
        contains("'shared/forge-central-token'"),
        reason: 'the central forge\'s token is the person\'s, shared by every host',
      );
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
      for (final need in <String>['drive', 'no-such-need', 'vault; rm', '']) {
        expect(
          () => SecretsFile(file).stopLines(host: 'checkout', project: 'checkout', needs: [need]),
          throwsFormatException,
          reason: need,
        );
      }
      expect(
        () => SecretsFile(file).stopLines(host: "a'b", project: "a'b", needs: ['keys']),
        throwsA(isA<HostFilesRefused>()),
      );
      expect(
        () => SecretsFile(file).stopLines(host: 'checkout', project: 'checkout', needs: []),
        throwsFormatException,
      );
      expect(
        () => SecretsFile(file).stopLines(host: 'checkout', project: 'checkout', needs: ['vault', 'vault-new']),
        throwsFormatException,
        reason: 'a new vault and an open one are never asked at once',
      );
      expect(
        () => SecretsFile(file).stopLines(host: 'checkout', project: 'checkout', needs: ['vault'], keys: ['forge']),
        throwsFormatException,
        reason: 'no key line where the host did not ask for its entries',
      );
      for (final name in <String>['_x', 'a b', "a'b", 'a/b', '']) {
        expect(
          () => SecretsFile(file).stopLines(host: 'checkout', project: 'checkout', needs: ['keys'], keys: [name]),
          throwsA(isA<HostFilesRefused>()),
          reason: name,
        );
      }
      expect(
        () =>
            SecretsFile(file)
                .stopLines(host: 'checkout', project: 'checkout', needs: ['keys'], keys: ['forge', 'forge']),
        throwsFormatException,
      );
      // Harm: a stop for a missing entry answered with no line, and `up` refusing the same way again.
      expect(
        () => SecretsFile(file).stopLines(host: 'checkout', project: 'checkout', needs: ['keys']),
        throwsFormatException,
        reason: 'only beside a new vault may the entries be none',
      );
      expect(
        SecretsFile(file).stopLines(host: 'checkout', project: 'checkout', needs: ['vault-new', 'keys']),
        isNotEmpty,
      );
    });
  });

  // Against the real keepassxc-cli: the file made, read back, and the host's key never printed.
  group('run with keepassxc-cli', () {
    final cli = Platform.environment['KEEPASSXC_CLI'] ?? SecretsFile.keepassxcCli;
    final skip = File(cli).existsSync() && Process.runSync('which', ['wg']).exitCode == 0
        ? null
        : 'needs keepassxc-cli at $cli (set KEEPASSXC_CLI) and wg';
    late Directory home;

    setUp(() async {
      home = await Directory.systemTemp.createTemp('porelo-secrets-test-');
    });

    tearDown(() async {
      if (await home.exists()) await home.delete(recursive: true);
    });

    Future<ProcessResult> run(
      String script,
      String master, {
      bool twice = false,
      Map<String, String>? environment,
    }) async {
      final process = await Process.start('bash', ['-c', script], environment: environment);
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

    Future<bool> entryExists(String kdbx, String entry, [String master = 'test-master']) async {
      final process = await Process.start(cli, ['show', kdbx, entry]);
      process.stdin.writeln(master);
      await process.stdin.close();
      await Future.wait([process.stdout.drain<void>(), process.stderr.drain<void>()]);
      return await process.exitCode == 0;
    }

    Future<ProcessResult> opensslResult(List<String> arguments, {String? input}) async {
      final process = await Process.start('/usr/bin/openssl', arguments, workingDirectory: home.path);
      final out = process.stdout.transform(utf8.decoder).join();
      final err = process.stderr.transform(utf8.decoder).join();
      if (input != null) process.stdin.write(input);
      await process.stdin.close();
      return ProcessResult(process.pid, await process.exitCode, await out, await err);
    }

    Future<String> openssl(List<String> arguments, {String? input}) async {
      final result = await opensslResult(arguments, input: input);
      expect(result.exitCode, 0, reason: '${arguments.first}: ${result.stderr}');
      return '${result.stdout}';
    }

    Future<String> certificateRequest() async {
      final key = await openssl(['genpkey', '-algorithm', 'EC', '-pkeyopt', 'ec_paramgen_curve:P-256']);
      return openssl([
        'req',
        '-new',
        '-key',
        '/dev/stdin',
        '-subj',
        '/CN=evil.example',
        '-addext',
        'subjectAltName=DNS:evil.example',
        '-addext',
        'basicConstraints=critical,CA:TRUE',
      ], input: key);
    }

    List<String> certificates(ProcessResult result) {
      expect(result.exitCode, 0, reason: '${result.stderr}');
      final line = '${result.stdout}'.trim();
      expect(line, startsWith('forge-certificate '));
      final pem = utf8.decode(base64Decode(line.substring('forge-certificate '.length)));
      final blocks = RegExp(r'-----BEGIN CERTIFICATE-----[^-]+-----END CERTIFICATE-----')
          .allMatches(pem)
          .map((m) => m.group(0)!)
          .toList();
      expect(pem, '${blocks.join('\n')}\n', reason: 'the feed contains only whole certificates joined by newlines');
      return blocks;
    }

    Future<String> preparedSecrets() async {
      final kdbx = path.join(home.path, 'secrets.kdbx');
      final made = await run(
        SecretsFile(kdbx, cli: cli).prepareHost(
          host: 'checkout',
          project: 'checkout',
          create: true,
          publicKeyOut: path.join(home.path, 'checkout.pub'),
        ),
        'm',
        twice: true,
      );
      expect(made.exitCode, 0, reason: '${made.stderr}');
      return kdbx;
    }

    // Harm: trusting one host's CA lets that host impersonate services on another host.
    test('each host keeps its own CA constrained to its name and network', () async {
      final kdbx = await preparedSecrets();
      final requests = '${await certificateRequest()}${await certificateRequest()}';
      final cas = <String>[];
      final leaves = <String>[];
      for (final host in ['checkout', 'second']) {
        final feed = SecretsFile(kdbx, cli: cli).stopLines(host: host, project: host, needs: ['forge-certificate']);
        final blocks = certificates(await run(feed, 'm', environment: {'request': requests}));
        cas.add(blocks.last);
        leaves.add(blocks.first);
        final constraints = await openssl(['x509', '-noout', '-ext', 'nameConstraints'], input: blocks.last);
        expect(constraints, contains('critical'));
        expect(constraints.trim().split('\n').map((line) => line.trim()).toList(), [
          'X509v3 Name Constraints: critical',
          'Permitted:',
          'DNS:$host.porelo.internal',
          'IP:10.73.0.0/255.255.255.0',
        ], reason: 'a CA is limited to exactly this host and network');
        expect(await show(kdbx, SecretsFile.forgeCa(host), 'm'), base64Encode(utf8.encode('${blocks.last}\n')));
        final again = certificates(await run(feed, 'm', environment: {'request': requests}));
        expect(again.last, blocks.last, reason: 'an existing CA is reused unchanged');
      }
      expect(cas[1], isNot(cas[0]), reason: 'each host has a lasting CA of its own');
      for (var i = 0; i < cas.length; i++) {
        await File(path.join(home.path, 'ca-$i.pem')).writeAsString('${cas[i]}\n');
        await File(path.join(home.path, 'leaf-$i.pem')).writeAsString('${leaves[i]}\n');
        expect(
          await openssl(['x509', '-noout', '-ext', 'keyUsage', '-in', 'leaf-$i.pem']),
          allOf(contains('critical'), contains('Digital Signature')),
          reason: 'the host refuses a server certificate without a critical digitalSignature key usage',
        );
        expect(
          await openssl(['verify', '-no-CApath', '-no-CAstore', '-CAfile', 'ca-$i.pem', 'leaf-$i.pem']),
          contains('OK'),
        );
        expect(
          (await opensslResult(['verify', '-no-CApath', '-no-CAstore', '-CAfile', 'ca-${1 - i}.pem', 'leaf-$i.pem']))
              .exitCode,
          isNot(0),
        );
      }
      await File(path.join(home.path, 'foreign.csr')).writeAsString(await certificateRequest());
      final caKey = utf8.decode(base64Decode(await show(kdbx, SecretsFile.forgeCaKey('checkout'), 'm')));
      for (final (why, name, address) in [
        ('another host name', 'forge.second.porelo.internal', '10.73.0.1'),
        ('another host network', 'forge.checkout.porelo.internal', '10.73.1.1'),
      ]) {
        await File(path.join(home.path, 'foreign.ext')).writeAsString(
          'subjectAltName=DNS:$name,IP:$address\nbasicConstraints=critical,CA:FALSE\nextendedKeyUsage=serverAuth\n',
        );
        final foreign = await openssl([
          'x509',
          '-req',
          '-in',
          'foreign.csr',
          '-subj',
          '/CN=$name',
          '-CA',
          'ca-0.pem',
          '-CAkey',
          '/dev/stdin',
          '-days',
          '365',
          '-set_serial',
          '1',
          '-extfile',
          'foreign.ext',
        ], input: caKey);
        await File(path.join(home.path, 'foreign.pem')).writeAsString(foreign);
        final refused = await opensslResult([
          'verify',
          '-no-CApath',
          '-no-CAstore',
          '-CAfile',
          'ca-0.pem',
          'foreign.pem',
        ]);
        expect(refused.exitCode, isNot(0), reason: '$why must fail even with the trusted CA signature');
        expect(
          '${refused.stderr}',
          contains('permitted subtree violation'),
          reason: 'the name constraint rejects $why',
        );
      }
    }, skip: skip);

    // Harm: accepting an incomplete or unverified request batch sends a partially trusted host setup.
    test('anything but two valid self-signed requests sends nothing', () async {
      final kdbx = await preparedSecrets();
      final first = await certificateRequest();
      final second = await certificateRequest();
      final signedBody = second.split('\n');
      final lastBody = signedBody.length - 3;
      signedBody[lastBody] = '${signedBody[lastBody][0] == 'A' ? 'B' : 'A'}${signedBody[lastBody].substring(1)}';
      final feed = SecretsFile(
        kdbx,
        cli: cli,
      ).stopLines(host: 'checkout', project: 'checkout', needs: ['vault', 'forge-certificate']);
      for (final (why, requests) in [
        ('no requests', ''),
        ('one request', first),
        ('three requests', '$first$second$first'),
        ('invalid signature', '$first${signedBody.join('\n')}'),
        (
          'malformed second request',
          '$first-----BEGIN CERTIFICATE REQUEST-----\nAAAA\n-----END CERTIFICATE REQUEST-----\n',
        ),
        ('text outside PEM', '$first$second\nunexpected'),
        ('truncated second request', '$first${second.replaceFirst('-----END CERTIFICATE REQUEST-----', '')}'),
      ]) {
        final refused = await run(feed, 'm', environment: {'request': requests});
        expect(refused.exitCode, isNot(0), reason: why);
        expect('${refused.stdout}', isEmpty, reason: '$why must send no part of the feed');
      }
    }, skip: skip);

    // Harm: a nonzero host network silently receives trust for the shared default network.
    test('a chosen network constrains the CA and both service addresses', () async {
      final kdbx = await preparedSecrets();
      final requests = '${await certificateRequest()}${await certificateRequest()}';
      final blocks = certificates(
        await run(
          SecretsFile(
            kdbx,
            cli: cli,
          ).stopLines(host: 'checkout', project: 'checkout', needs: ['forge-certificate'], networkNumber: 255),
          'm',
          environment: {'request': requests},
        ),
      );
      expect(
        await openssl(['x509', '-noout', '-ext', 'nameConstraints'], input: blocks.last),
        contains('IP:10.73.255.0/255.255.255.0'),
      );
      for (final pem in blocks.take(2)) {
        expect(
          await openssl(['x509', '-noout', '-ext', 'subjectAltName'], input: pem),
          contains('IP Address:10.73.255.1'),
        );
      }
    }, skip: skip);

    // Harm: replacing an existing CA breaks the trust already installed on the person's other computers.
    test('an existing CA is reused with its original constraints and key', () async {
      final kdbx = await preparedSecrets();
      final key = await openssl(['genpkey', '-algorithm', 'EC', '-pkeyopt', 'ec_paramgen_curve:P-256']);
      final ca = await openssl([
        'req',
        '-x509',
        '-new',
        '-key',
        '/dev/stdin',
        '-subj',
        '/CN=Existing CA',
        '-days',
        '3650',
        '-addext',
        'basicConstraints=critical,CA:TRUE,pathlen:0',
        '-addext',
        'nameConstraints=critical,permitted;DNS:porelo.internal',
      ], input: key);
      await cliIn(
        kdbx,
        ['add', '-p', kdbx, SecretsFile.forgeCaKey('checkout')],
        'm',
        then: base64Encode(utf8.encode(key)),
      );
      await cliIn(kdbx, ['add', '-p', kdbx, SecretsFile.forgeCa('checkout')], 'm', then: base64Encode(utf8.encode(ca)));
      final blocks = certificates(
        await run(
          SecretsFile(kdbx, cli: cli).stopLines(host: 'checkout', project: 'checkout', needs: ['forge-certificate']),
          'm',
          environment: {'request': '${await certificateRequest()}${await certificateRequest()}'},
        ),
      );
      expect('${blocks.last}\n', ca, reason: 'existing trust remains byte for byte');
      expect(
        await show(kdbx, SecretsFile.forgeCaKey('checkout'), 'm') == base64Encode(utf8.encode(key)),
        isTrue,
        reason: 'the existing signing key remains unchanged',
      );
    }, skip: skip);

    // Harm: a lasting login password leaks into the terminal or is silently replaced on another host.
    test('the lasting forge password is typed once and kept only in the shared entry', () async {
      final kdbx = await preparedSecrets();
      final random = Random.secure();
      final password = base64Encode(List<int>.generate(24, (_) => random.nextInt(256)));
      final script = SecretsFile(kdbx, cli: cli).forgePasswordLine();
      final made = await run(script, 'm\n$password');
      expect(made.exitCode, 0, reason: '${made.stderr}');
      expect(await entryExists(kdbx, 'shared/forge-password', 'm'), isTrue);
      expect(
        await show(kdbx, 'shared/forge-password', 'm') == password,
        isTrue,
        reason: 'the shared entry holds the typed password',
      );
      expect('${made.stdout}' == '$password\n', isTrue, reason: 'only the pipe gets the password');
      expect('${made.stderr}'.contains(password), isFalse, reason: 'nothing of the password is logged');
      final again = await run(script, 'm');
      expect(again.exitCode, 0, reason: '${again.stderr}');
      expect(
        '${again.stdout}' == '$password\n',
        isTrue,
        reason: 'a later host reuses it without another password prompt',
      );
      final wrong = await run(script, 'wrong');
      expect(wrong.exitCode, isNot(0));
      expect('${wrong.stdout}', isEmpty);
    }, skip: skip);

    // Harm: an empty or multiline stored password reaches a privileged host command as an unintended input.
    test('an empty or multiline forge password is refused without a feed', () async {
      final kdbx = await preparedSecrets();
      final script = SecretsFile(kdbx, cli: cli).forgePasswordLine();
      final empty = await run(script, 'm\n');
      expect(empty.exitCode, isNot(0));
      expect('${empty.stdout}', isEmpty);
      expect(await entryExists(kdbx, 'shared/forge-password', 'm'), isFalse);
      await cliIn(kdbx, ['add', '-p', kdbx, 'shared/forge-password'], 'm', then: '');
      final storedEmpty = await run(script, 'm\nunused');
      expect(storedEmpty.exitCode, isNot(0));
      expect('${storedEmpty.stdout}', isEmpty);
      await cliIn(kdbx, ['edit', '-p', kdbx, 'shared/forge-password'], 'm', then: 'first\rsecond');
      final multiline = await run(script, 'm');
      expect(multiline.exitCode, isNot(0));
      expect('${multiline.stdout}', isEmpty);
    }, skip: skip);

    final moves = {
      'hosts/checkout/vault-passphrase': 'projects/checkout/vault-passphrase',
      'hosts/checkout/keys/forge': 'projects/checkout/keys/forge',
      'hosts/checkout/keys/ci.key': 'projects/checkout/keys/ci.key',
      'hosts/checkout/keys/legacy': 'projects/checkout/keys/legacy',
      'shared/forge-ca-key': 'hosts/checkout/forge-ca-key',
      'shared/forge-ca': 'hosts/checkout/forge-ca',
    };

    Future<Map<String, String>> legacyCa() async {
      final key = await openssl(['genpkey', '-algorithm', 'EC', '-pkeyopt', 'ec_paramgen_curve:P-256']);
      final cert = await openssl([
        'req',
        '-x509',
        '-new',
        '-key',
        '/dev/stdin',
        '-subj',
        '/CN=Porelo forge CA',
        '-days',
        '3650',
        '-addext',
        'basicConstraints=critical,CA:TRUE,pathlen:0',
        '-addext',
        'keyUsage=critical,keyCertSign,cRLSign',
        '-addext',
        'nameConstraints=critical,permitted;DNS:porelo.internal,permitted;IP:10.73.0.0/255.255.255.0',
      ], input: key);
      return {
        'shared/forge-ca-key': base64Encode(utf8.encode(key)),
        'shared/forge-ca': base64Encode(utf8.encode(cert)),
      };
    }

    Future<Map<String, String>> legacyFile(String kdbx) async {
      await cliIn(kdbx, ['db-create', '-p', kdbx], 'test-master', then: 'test-master');
      for (final group in ['hosts', 'hosts/checkout', 'hosts/checkout/keys', 'hosts/other', 'shared']) {
        await cliIn(kdbx, ['mkdir', kdbx, group], 'test-master');
      }
      final values = {
        for (final entry in moves.keys) entry: base64Encode(utf8.encode('fixture value for $entry')),
        'hosts/checkout/wireguard': base64Encode(List<int>.filled(32, 7)),
        'hosts/other/vault-passphrase': 'other-project-fixture',
        'shared/forge-central-token': 'central-token-fixture',
        ...await legacyCa(),
      };
      for (final entry in values.entries) {
        await cliIn(kdbx, ['add', '-p', kdbx, entry.key], 'test-master', then: entry.value);
      }
      return values;
    }

    // A migrated CA must never sign a leaf outside its permitted network.
    test('a migrated CA signs only on its original permitted network', () async {
      final kdbx = path.join(home.path, 'secrets.kdbx');
      final original = await legacyFile(kdbx);
      final requests = '${await certificateRequest()}${await certificateRequest()}';
      final caout = path.join(home.path, 'public-ca.pem');
      final refused = await run(
        SecretsFile(
          kdbx,
          cli: cli,
        ).stopLines(host: 'checkout', project: 'checkout', needs: ['forge-certificate'], networkNumber: 7),
        'test-master',
        environment: {'request': requests, 'caout': caout},
      );
      expect(refused.exitCode, isNot(0), reason: 'the old CA cannot permit network 7');
      expect(refused.stdout, isEmpty, reason: 'no invalid certificate reaches the host');
      expect(refused.stderr, contains('remove the old entries so a new CA is made'));
      expect(await File(caout).exists(), isFalse);
      final blocks = certificates(
        await run(
          SecretsFile(kdbx, cli: cli).stopLines(host: 'checkout', project: 'checkout', needs: ['forge-certificate']),
          'test-master',
          environment: {'request': requests},
        ),
      );
      expect(base64Encode(utf8.encode('${blocks.last}\n')), original['shared/forge-ca']);
      await File(path.join(home.path, 'legacy-ca.pem')).writeAsString(blocks.last);
      for (var i = 0; i < 2; i++) {
        await File(path.join(home.path, 'leaf.pem')).writeAsString(blocks[i]);
        expect(
          await openssl(['verify', '-no-CApath', '-no-CAstore', '-CAfile', 'legacy-ca.pem', 'leaf.pem']),
          contains('OK'),
        );
      }
    }, skip: skip);

    // Legacy project identifiers must retain their host key and teardown identity.
    test('project-mode secrets accept uppercase dots and underscores', () async {
      final kdbx = path.join(home.path, 'secrets.kdbx');
      final out = path.join(home.path, 'host.pub');
      for (final project in ['Upper', 'with.dot', 'under_score']) {
        final prepared = await run(
          SecretsFile(
            kdbx,
            cli: cli,
          ).prepareHost(host: project, project: project, create: !File(kdbx).existsSync(), publicKeyOut: out),
          'm',
          twice: !File(kdbx).existsSync(),
        );
        expect(prepared.exitCode, 0, reason: '${prepared.stderr}');
        expect(await entryExists(kdbx, 'hosts/$project/wireguard', 'm'), isTrue);
        expect(await entryExists(kdbx, 'projects/$project/vault-passphrase', 'm'), isTrue);
      }
    }, skip: skip);

    // Server administration must not create or move secrets belonging to an unrelated project.
    test('server-only preparation and stops leave project secrets untouched', () async {
      final kdbx = path.join(home.path, 'secrets.kdbx');
      final out = path.join(home.path, 'host.pub');
      final fresh = await run(
        SecretsFile(kdbx, cli: cli).prepareHost(host: 'checkout', project: '', create: true, publicKeyOut: out),
        'm',
        twice: true,
      );
      expect(fresh.exitCode, 0, reason: '${fresh.stderr}');
      expect(await entryExists(kdbx, 'projects/checkout/vault-passphrase', 'm'), isFalse);
      await File(kdbx).delete();
      final values = await legacyFile(kdbx);
      final prepared = await run(
        SecretsFile(kdbx, cli: cli).prepareHost(host: 'checkout', project: '', create: false, publicKeyOut: out),
        'test-master',
      );
      expect(prepared.exitCode, 0, reason: '${prepared.stderr}');
      final stopped = await run(
        SecretsFile(kdbx, cli: cli).stopLines(host: 'checkout', project: '', needs: ['wireguard']),
        'test-master',
      );
      expect(stopped.exitCode, 0, reason: '${stopped.stderr}');
      for (final source in moves.keys.where((name) => name.startsWith('hosts/'))) {
        expect(await show(kdbx, source, 'test-master'), values[source]);
        expect(await entryExists(kdbx, moves[source]!), isFalse);
      }
    }, skip: skip);

    // Moving names must preserve every value, including keys the current stop does not request.
    test('moves every legacy value once and leaves the database unchanged on a second stop', () async {
      final kdbx = path.join(home.path, 'secrets.kdbx');
      final values = await legacyFile(kdbx);
      final script = SecretsFile(
        kdbx,
        cli: cli,
      ).stopLines(host: 'checkout', project: 'checkout', needs: ['vault', 'wireguard']);

      final first = await run(script, 'test-master');

      expect(first.exitCode, 0, reason: '${first.stderr}');
      for (final move in moves.entries) {
        expect(await entryExists(kdbx, move.value), isTrue, reason: '${move.value} was copied');
        expect(
          await show(kdbx, move.value, 'test-master') == values[move.key],
          isTrue,
          reason: '${move.value} retains its value',
        );
        expect(await entryExists(kdbx, move.key), isFalse, reason: '${move.key} was removed after copying');
      }
      for (final entry in values.entries.where((entry) => !moves.containsKey(entry.key))) {
        expect(await show(kdbx, entry.key, 'test-master') == entry.value, isTrue, reason: '${entry.key} stays intact');
      }
      for (final value in values.values) {
        expect('${first.stderr}'.contains(value), isFalse, reason: 'no entry value is logged');
        expect(script.contains(value), isFalse, reason: 'no entry value is in a command line');
      }
      final before = await File(kdbx).readAsBytes();

      final second = await run(script, 'test-master');

      expect(second.exitCode, 0, reason: '${second.stderr}');
      expect(second.stdout == first.stdout, isTrue, reason: 'the same values reach the stop');
      expect(await File(kdbx).readAsBytes(), before, reason: 'no database write on the second run');
    }, skip: skip);

    // A destination already kept by the person must never be replaced, even by an identical legacy value.
    test('keeps both entries and reports every legacy destination that already exists', () async {
      final kdbx = path.join(home.path, 'secrets.kdbx');
      final values = await legacyFile(kdbx);
      for (final group in ['projects', 'projects/checkout', 'projects/checkout/keys']) {
        await cliIn(kdbx, ['mkdir', kdbx, group], 'test-master');
      }
      final destinations = <String, String>{};
      for (final move in moves.entries) {
        final value = move.key.endsWith('/legacy') ? values[move.key]! : 'destination-${values[move.key]}';
        destinations[move.value] = value;
        await cliIn(kdbx, ['add', '-p', kdbx, move.value], 'test-master', then: value);
      }
      final before = await File(kdbx).readAsBytes();
      final script = SecretsFile(kdbx, cli: cli).stopLines(host: 'checkout', project: 'checkout', needs: ['wireguard']);

      final result = await run(script, 'test-master');

      expect(result.exitCode, 0, reason: '${result.stderr}');
      for (final move in moves.entries) {
        expect('${result.stderr}', contains('Both ${move.key} and ${move.value} exist; neither was changed.'));
        expect(
          await show(kdbx, move.key, 'test-master') == values[move.key],
          isTrue,
          reason: '${move.key} keeps its value',
        );
        expect(
          await show(kdbx, move.value, 'test-master') == destinations[move.value],
          isTrue,
          reason: '${move.value} keeps its value',
        );
      }
      expect(await File(kdbx).readAsBytes(), before, reason: 'conflicts cause no database writes');
    }, skip: skip);

    // A failed write must leave the source usable and send no partial feed to the host.
    test('keeps the legacy value when copying any kind of entry fails', () async {
      for (final target in [
        'projects/checkout/vault-passphrase',
        'projects/checkout/keys/forge',
        'hosts/checkout/forge-ca-key',
        'hosts/checkout/forge-ca',
      ]) {
        final kdbx = path.join(home.path, 'failure-${moves.values.toList().indexOf(target)}.kdbx');
        final values = await legacyFile(kdbx);
        final wrapper = await File(path.join(home.path, 'failing-cli')).writeAsString(
          [
            '#!/bin/bash',
            'if [ "\$1" = add ] && [ "\${!#}" = ${quoteForAShell(target)} ]; then exit 74; fi',
            'exec ${quoteForAShell(cli)} "\$@"',
          ].join('\n'),
        );
        expect((await Process.run('/usr/bin/chmod', ['700', wrapper.path])).exitCode, 0);
        final script = SecretsFile(
          kdbx,
          cli: wrapper.path,
        ).stopLines(host: 'checkout', project: 'checkout', needs: ['wireguard']);

        final result = await run(script, 'test-master');

        expect(result.exitCode, isNot(0), reason: 'the failed copy to $target stops the script');
        expect('${result.stdout}', isEmpty, reason: 'no partial feed');
        final source = moves.entries.singleWhere((move) => move.value == target).key;
        expect(
          await show(kdbx, source, 'test-master') == values[source],
          isTrue,
          reason: '$source survives the failed copy',
        );
        expect(await entryExists(kdbx, target), isFalse, reason: 'no destination was written');
      }
    }, skip: skip);

    // A successful add alone cannot justify deleting the only verified copy of a value.
    test('keeps the source when its copied value cannot be read back unchanged', () async {
      for (final failure in ['unreadable', 'empty']) {
        final kdbx = path.join(home.path, '$failure.kdbx');
        final values = await legacyFile(kdbx);
        final wrapper = await File(path.join(home.path, 'readback-cli')).writeAsString(
          [
            '#!/bin/bash',
            'if [ "\$1" = show ] && [ "\$2" = -s ] && '
                '[ "\${!#}" = projects/checkout/vault-passphrase ]; then',
            failure == 'unreadable' ? '  exit 74' : '  exit 0',
            'fi',
            'exec ${quoteForAShell(cli)} "\$@"',
          ].join('\n'),
        );
        expect((await Process.run('/usr/bin/chmod', ['700', wrapper.path])).exitCode, 0);
        final script = SecretsFile(
          kdbx,
          cli: wrapper.path,
        ).stopLines(host: 'checkout', project: 'checkout', needs: ['wireguard']);

        final result = await run(script, 'test-master');

        expect(result.exitCode, isNot(0), reason: '$failure read-back prevents removing the source');
        expect('${result.stdout}', isEmpty, reason: 'no partial feed');
        for (final entry in ['hosts/checkout/vault-passphrase', 'projects/checkout/vault-passphrase']) {
          expect(
            await show(kdbx, entry, 'test-master') == values['hosts/checkout/vault-passphrase'],
            isTrue,
            reason: '$entry retains the original value',
          );
        }
      }
    }, skip: skip);

    // Preparation must reuse legacy values before generating anything that would hide them behind a conflict.
    test('preparing an existing file moves its passphrase and preserves its keys', () async {
      final kdbx = path.join(home.path, 'secrets.kdbx');
      final values = await legacyFile(kdbx);
      final out = path.join(home.path, 'checkout.pub');
      final chosen = await File(path.join(home.path, 'token')).writeAsBytes([9]);
      final script = SecretsFile(kdbx, cli: cli).prepareHost(
        host: 'checkout',
        project: 'checkout',
        create: false,
        publicKeyOut: out,
        keys: {'forge': chosen.path},
      );
      final before = await File(kdbx).readAsBytes();

      final refused = await run(script, 'test-master');

      expect(refused.exitCode, isNot(0), reason: 'a different file must not replace the legacy key');
      expect(await File(kdbx).readAsBytes(), before, reason: 'input refusal precedes migration');
      await chosen.writeAsBytes(base64Decode(values['hosts/checkout/keys/forge']!));

      final result = await run(script, 'test-master');

      expect(result.exitCode, 0, reason: '${result.stderr}');
      for (final move in moves.entries) {
        expect(
          await show(kdbx, move.value, 'test-master') == values[move.key],
          isTrue,
          reason: '${move.value} was reused',
        );
        expect(await entryExists(kdbx, move.key), isFalse, reason: '${move.key} was moved');
      }
      expect((await File(out).readAsString()).trim(), await HostFiles.publicKey(values['hosts/checkout/wireguard']!));
    }, skip: skip);

    // An SSH address or a project must not select another host's WireGuard key or CA entries.
    test('a stop uses its host name separately from the legacy project name', () async {
      final kdbx = path.join(home.path, 'secrets.kdbx');
      final values = await legacyFile(kdbx);
      final private = base64Encode(List<int>.filled(32, 9));
      await cliIn(kdbx, ['mkdir', kdbx, 'hosts/rented-box'], 'test-master');
      await cliIn(kdbx, ['add', '-p', kdbx, 'hosts/rented-box/wireguard'], 'test-master', then: private);
      final script = SecretsFile(
        kdbx,
        cli: cli,
      ).stopLines(host: 'rented-box', project: 'checkout', needs: ['vault', 'wireguard', 'keys'], keys: ['forge']);

      final result = await run(script, 'test-master');

      expect(result.exitCode, 0, reason: '${result.stderr}');
      final lines = '${result.stdout}'.trim().split('\n');
      expect(
        lines.join('\n') ==
            [
              'vault ${base64Encode(utf8.encode(values['hosts/checkout/vault-passphrase']!))}',
              'wireguard ${base64Encode(utf8.encode(private))}',
              'key forge ${values['hosts/checkout/keys/forge']}',
            ].join('\n'),
        isTrue,
        reason: 'only this host key and this project\'s values are fed',
      );
      for (final name in ['forge-ca-key', 'forge-ca']) {
        expect(
          await show(kdbx, 'hosts/rented-box/$name', 'test-master') == values['shared/$name'],
          isTrue,
          reason: 'the CA entry belongs to the host',
        );
        expect(await entryExists(kdbx, 'shared/$name'), isFalse);
        expect(await entryExists(kdbx, 'hosts/checkout/$name'), isFalse);
      }
      expect(
        await show(kdbx, 'hosts/checkout/wireguard', 'test-master') == values['hosts/checkout/wireguard'],
        isTrue,
        reason: 'another host\'s key stays intact',
      );
    }, skip: skip);

    // Sharing a host must not rotate its key or reuse one project's passphrase or key file for another project.
    test('keeps two projects separate under the same host without replacing its WireGuard key', () async {
      final kdbx = path.join(home.path, 'secrets.kdbx');
      final out = path.join(home.path, 'host.pub');
      final passes = <String, String>{};
      String? hostKey;
      for (final project in ['First.project', 'second']) {
        final bytes = utf8.encode('fixture for $project');
        final chosen = await File(path.join(home.path, '$project-token')).writeAsBytes(bytes);
        final script = SecretsFile(kdbx, cli: cli).prepareHost(
          host: 'rented-box',
          project: project,
          create: hostKey == null,
          publicKeyOut: out,
          keys: {'forge': chosen.path},
        );

        final result = await run(script, 'test-master', twice: hostKey == null);

        expect(result.exitCode, 0, reason: '${result.stderr}');
        final kept = await show(kdbx, 'hosts/rented-box/wireguard', 'test-master');
        hostKey ??= kept;
        expect(kept == hostKey, isTrue, reason: 'one host retains one WireGuard key');
        passes[project] = await show(kdbx, 'projects/$project/vault-passphrase', 'test-master');
        expect(
          await show(kdbx, 'projects/$project/keys/forge', 'test-master') == base64Encode(bytes),
          isTrue,
          reason: 'the project retains its own key file',
        );
      }
      expect(passes.values.first == passes.values.last, isFalse, reason: 'each project has its own passphrase');
      for (final entry in passes.entries) {
        final unlocked = await run(SecretsFile(kdbx, cli: cli).unlockLine(project: entry.key), 'test-master');
        expect(unlocked.exitCode, 0, reason: '${unlocked.stderr}');
        expect('${unlocked.stdout}' == '${entry.value}\n', isTrue, reason: 'the original project passphrase stays');
      }
    }, skip: skip);

    test('makes the file, the host key and its passphrase, and writes out only the public half', () async {
      final kdbx = path.join(home.path, 'secrets.kdbx');
      final out = path.join(home.path, 'checkout.pub');
      final script = SecretsFile(
        kdbx,
        cli: cli,
      ).prepareHost(host: 'checkout', project: 'checkout', create: true, publicKeyOut: out);

      final result = await run(script, 'test-master', twice: true);

      expect(result.exitCode, 0, reason: 'the script ran: ${result.stderr}');
      final private = await show(kdbx, 'hosts/checkout/wireguard', 'test-master');
      expect(await HostFiles.publicKey(private), (await File(out).readAsString()).trim(), reason: 'its public half');
      expect('${result.stdout}${result.stderr}', isNot(contains(private)), reason: 'the key is never printed');
      expect(await show(kdbx, 'projects/checkout/vault-passphrase', 'test-master'), isNotEmpty);
      expect((await File(out).stat()).modeString(), 'rw-------');
    }, skip: skip);

    test('keeps the key a second run finds, so the tunnel stays the same', () async {
      final kdbx = path.join(home.path, 'secrets.kdbx');
      final out = path.join(home.path, 'checkout.pub');
      final first = SecretsFile(
        kdbx,
        cli: cli,
      ).prepareHost(host: 'checkout', project: 'checkout', create: true, publicKeyOut: out);
      expect((await run(first, 'test-master', twice: true)).exitCode, 0);
      final before = await File(out).readAsString();

      final again = SecretsFile(
        kdbx,
        cli: cli,
      ).prepareHost(host: 'checkout', project: 'checkout', create: false, publicKeyOut: out);
      final result = await run(again, 'test-master');

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(await File(out).readAsString(), before, reason: 'the same host key, not a new one');
    }, skip: skip);

    // Harm: a key left in the clear on the drive beside the file, or the file's key silently replaced by another.
    test('a drive key beside the file is removed when it is the same, and refused when it differs', () async {
      final kdbx = path.join(home.path, 'secrets.kdbx');
      final out = path.join(home.path, 'checkout.pub');
      final drive = File(path.join(home.path, 'wireguard.key'));
      final made = SecretsFile(
        kdbx,
        cli: cli,
      ).prepareHost(host: 'checkout', project: 'checkout', create: true, publicKeyOut: out);
      expect((await run(made, 'm', twice: true)).exitCode, 0);
      final kept = await show(kdbx, 'hosts/checkout/wireguard', 'm');

      await drive.writeAsString('$kept\n');
      final same = SecretsFile(kdbx, cli: cli).prepareHost(
        host: 'checkout',
        project: 'checkout',
        create: false,
        publicKeyOut: out,
        migrateKeyFrom: drive.path,
      );
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
          SecretsFile(kdbx, cli: cli).prepareHost(
            host: 'checkout',
            project: 'checkout',
            create: true,
            publicKeyOut: out,
            migrateKeyFrom: drive.path,
          ),
          'm',
          twice: true,
        );
        expect(broken.exitCode, isNot(0), reason: 'a drive file that is no key is refused');
        expect(await drive.readAsString(), 'not a key\n', reason: 'and kept as it was');
        expect(await File(kdbx).exists(), isFalse, reason: 'and no file made before the refusal');

        await drive.writeAsString('$original\n');
        final moved = await run(
          SecretsFile(kdbx, cli: cli).prepareHost(
            host: 'checkout',
            project: 'checkout',
            create: true,
            publicKeyOut: out,
            migrateKeyFrom: drive.path,
          ),
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
          SecretsFile(kdbx, cli: cli).prepareHost(
            host: 'checkout',
            project: 'checkout',
            create: false,
            publicKeyOut: out,
            migrateKeyFrom: drive.path,
          ),
          'm',
        );
        expect(linked.exitCode, isNot(0), reason: 'a link on the drive is outside input and refused');
        expect(await target.exists(), isTrue);
        expect(FileSystemEntity.typeSync(drive.path, followLinks: false), FileSystemEntityType.link, reason: 'kept');

        await Link(drive.path).delete();
        await Directory(drive.path).create();
        final folder = await run(
          SecretsFile(kdbx, cli: cli).prepareHost(
            host: 'checkout',
            project: 'checkout',
            create: false,
            publicKeyOut: out,
            migrateKeyFrom: drive.path,
          ),
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
        SecretsFile(kdbx, cli: cli).prepareHost(
          host: 'checkout',
          project: 'checkout',
          create: true,
          publicKeyOut: out,
          keys: {'forge': chosen.path},
        ),
        'm',
        twice: true,
      );
      expect(made.exitCode, 0, reason: '${made.stderr}');
      expect(await show(kdbx, 'projects/checkout/keys/forge', 'm'), base64Encode([1, 2, 3, 250]));
      expect(await chosen.exists(), isTrue, reason: 'the person\'s own file stays theirs');

      final link = path.join(home.path, 'link-token');
      await Link(link).create(chosen.path);
      final linked = await run(
        SecretsFile(
          kdbx,
          cli: cli,
        ).prepareHost(host: 'checkout', project: 'checkout', create: false, publicKeyOut: out, keys: {'other': link}),
        'm',
      );
      expect(linked.exitCode, isNot(0), reason: 'a link is refused');
      final gone = await run(
        SecretsFile(kdbx, cli: cli).prepareHost(
          host: 'checkout',
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
        SecretsFile(kdbx, cli: cli).prepareHost(
          host: 'checkout',
          project: 'checkout',
          create: false,
          publicKeyOut: out,
          keys: {'other': empty.path},
        ),
        'm',
      );
      expect(none.exitCode, isNot(0), reason: 'an empty file would be an entry the stop cannot send');

      final real = await Directory(path.join(home.path, 'real')).create();
      await File(path.join(real.path, 'token')).writeAsBytes([4]);
      await Link(path.join(home.path, 'via')).create(real.path);
      final through = await run(
        SecretsFile(kdbx, cli: cli).prepareHost(
          host: 'checkout',
          project: 'checkout',
          create: false,
          publicKeyOut: out,
          keys: {'other': path.join(home.path, 'via', 'token')},
        ),
        'm',
      );
      expect(through.exitCode, isNot(0), reason: 'a folder on the way that is a link is refused too');
      expect(
        await entryExists(kdbx, 'projects/checkout/keys/other', 'm'),
        isFalse,
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
          SecretsFile(kdbx, cli: cli).prepareHost(host: 'first', project: 'first', create: true, publicKeyOut: out),
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
          SecretsFile(kdbx, cli: cli).prepareHost(
            host: project,
            project: project,
            create: false,
            publicKeyOut: out,
            keys: {'forge': chosen.path},
          ),
          'm',
        );
        expect(refused.exitCode, isNot(0), reason: project);
        expect(
          '${refused.stderr}',
          contains(value.isEmpty ? 'has an empty hosts/other/wireguard' : 'keeps no WireGuard key'),
          reason: 'what to mend is named',
        );
        for (final entry in ['projects/$project/vault-passphrase', 'projects/$project/keys/forge']) {
          expect(await entryExists(kdbx, entry, 'm'), isFalse, reason: '$entry not added before the refusal');
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
          SecretsFile(kdbx, cli: cli).prepareHost(
            host: 'checkout',
            project: 'checkout',
            create: true,
            publicKeyOut: out,
            keys: {'forge': first.path},
          ),
          'm',
          twice: true,
        )).exitCode,
        0,
      );
      final kept = await show(kdbx, 'hosts/checkout/wireguard', 'm');
      await drive.writeAsString('$kept\n');

      final other = await run(
        SecretsFile(kdbx, cli: cli).prepareHost(
          host: 'checkout',
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
      expect(await show(kdbx, 'projects/checkout/keys/forge', 'm'), base64Encode([1, 2, 3]));
      expect(
        await entryExists(kdbx, 'projects/checkout/keys/ci', 'm'),
        isFalse,
        reason: 'nothing added before the refusal',
      );

      final same = await run(
        SecretsFile(kdbx, cli: cli).prepareHost(
          host: 'checkout',
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
        SecretsFile(kdbx, cli: cli).prepareHost(host: 'checkout', project: 'checkout', create: true, publicKeyOut: out),
        '',
        twice: true,
      );
      expect(result.exitCode, isNot(0));
      expect(await File(kdbx).exists(), isFalse);
    }, skip: skip);

    // Harm: a host given the wrong secret, or a missing one, which the stop refuses only after the person typed.
    // Harm: the vault passphrase typed by hand, or more than it sent to the host's `porelo vault unlock`.
    test('the unlock line is the vault passphrase alone, and a missing entry gives none', () async {
      final kdbx = path.join(home.path, 'secrets.kdbx');
      final out = path.join(home.path, 'checkout.pub');
      expect(
        (await run(
          SecretsFile(
            kdbx,
            cli: cli,
          ).prepareHost(host: 'checkout', project: 'checkout', create: true, publicKeyOut: out),
          'm',
          twice: true,
        )).exitCode,
        0,
      );
      final passphrase = await show(kdbx, 'projects/checkout/vault-passphrase', 'm');

      final fed = await run(SecretsFile(kdbx, cli: cli).unlockLine(project: 'checkout'), 'm');
      expect(fed.exitCode, 0, reason: '${fed.stderr}');
      expect('${fed.stdout}', '$passphrase\n');
      expect('${fed.stderr}', isNot(contains(passphrase)), reason: 'nothing of it on the terminal');

      final wrong = await run(SecretsFile(kdbx, cli: cli).unlockLine(project: 'checkout'), 'not it');
      expect(wrong.exitCode, isNot(0));
      expect('${wrong.stdout}', isEmpty, reason: 'no line from a file that did not open');

      // A mistyped master password is asked again in the same terminal, three times at most.
      final again = await run(SecretsFile(kdbx, cli: cli).unlockLine(project: 'checkout'), 'not it\nm');
      expect(again.exitCode, 0, reason: '${again.stderr}');
      expect('${again.stdout}', '$passphrase\n');
      expect('${again.stderr}', contains('type it again'));
      final thrice = await run(SecretsFile(kdbx, cli: cli).unlockLine(project: 'checkout'), 'a\nb\nc\nm');
      expect(thrice.exitCode, isNot(0));
      expect('${thrice.stdout}', isEmpty);
      expect('${thrice.stderr}', contains('did not open with that password three times'));

      final missing = await run(SecretsFile(kdbx, cli: cli).unlockLine(project: 'other'), 'm');
      expect(missing.exitCode, isNot(0));
      expect('${missing.stdout}', isEmpty, reason: 'no line at all when the entry is missing');
    }, skip: skip);

    test('the stop\'s lines carry each entry base64, in the agreed form, and a missing entry gives none', () async {
      final kdbx = path.join(home.path, 'secrets.kdbx');
      final out = path.join(home.path, 'checkout.pub');
      expect(
        (await run(
          SecretsFile(
            kdbx,
            cli: cli,
          ).prepareHost(host: 'checkout', project: 'checkout', create: true, publicKeyOut: out),
          'm',
          twice: true,
        )).exitCode,
        0,
      );
      final key = await show(kdbx, 'hosts/checkout/wireguard', 'm');
      final passphrase = await show(kdbx, 'projects/checkout/vault-passphrase', 'm');

      final fed = await run(
        SecretsFile(kdbx, cli: cli).stopLines(host: 'checkout', project: 'checkout', needs: ['vault-new', 'wireguard']),
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
        SecretsFile(kdbx, cli: cli).stopLines(host: 'checkout', project: 'checkout', needs: ['vault-new', 'keys']),
        'm',
      );
      expect(none.exitCode, 0, reason: '${none.stderr}');
      expect('${none.stdout}'.trim().split('\n'), hasLength(1), reason: 'the passphrase alone');

      final missing = await run(
        SecretsFile(kdbx, cli: cli).stopLines(host: 'other', project: 'other', needs: ['vault']),
        'm',
      );
      expect(missing.exitCode, isNot(0));
      expect('${missing.stdout}', isEmpty, reason: 'no line at all when an entry is missing');

      // The vault entries' files, kept base64 in the group, go out as they are, one line each.
      await cliIn(kdbx, ['mkdir', kdbx, 'projects/checkout/keys'], 'm');
      await cliIn(
        kdbx,
        ['add', '-p', kdbx, 'projects/checkout/keys/forge'],
        'm',
        then: base64Encode(utf8.encode('token-bytes')),
      );
      await cliIn(kdbx, ['add', '-p', kdbx, 'projects/checkout/keys/ci.key'], 'm', then: base64Encode([0, 1, 2, 255]));
      // An entry kept from an earlier setup that machine.yml no longer names.
      await cliIn(kdbx, ['add', '-p', kdbx, 'projects/checkout/keys/legacy'], 'm', then: base64Encode([9]));
      final keys = await run(
        SecretsFile(
          kdbx,
          cli: cli,
        ).stopLines(host: 'checkout', project: 'checkout', needs: ['vault', 'keys'], keys: ['forge', 'ci.key']),
        'm',
      );
      expect(keys.exitCode, 0, reason: '${keys.stderr}');
      expect('${keys.stdout}'.trim().split('\n').skip(1).toList(), <String>[
        'key forge ${base64Encode(utf8.encode('token-bytes'))}',
        'key ci.key ${base64Encode([0, 1, 2, 255])}',
      ], reason: 'the entries machine.yml names, and no other');

      // A value kept by hand that is no whole base64 sends nothing.
      for (final (name, value) in [('plain', 'token'), ('short', 'a'), ('cut', 'ab=')]) {
        await cliIn(kdbx, ['add', '-p', kdbx, 'projects/checkout/keys/$name'], 'm', then: value);
        final refused = await run(
          SecretsFile(
            kdbx,
            cli: cli,
          ).stopLines(host: 'checkout', project: 'checkout', needs: ['vault', 'keys'], keys: ['forge', name]),
          'm',
        );
        expect(refused.exitCode, isNot(0), reason: value);
        expect('${refused.stdout}', isEmpty, reason: 'no line at all for $value');
        expect('${refused.stderr}', contains('projects/checkout/keys/$name is not base64'));
      }
      expect('${missing.stderr}', contains('projects/other/vault-passphrase'), reason: 'what is missing is named');
    }, skip: skip);

    // Harm: a host chooses its certificate's identity or receives a homeserver certificate for the forge's key.
    test('two requests are signed for their own keys and host names in the agreed order', () async {
      final kdbx = path.join(home.path, 'secrets.kdbx');
      final out = path.join(home.path, 'checkout.pub');
      expect(
        (await run(
          SecretsFile(
            kdbx,
            cli: cli,
          ).prepareHost(host: 'checkout', project: 'checkout', create: true, publicKeyOut: out),
          'm',
          twice: true,
        )).exitCode,
        0,
      );
      final key = await openssl(['genpkey', '-algorithm', 'EC', '-pkeyopt', 'ec_paramgen_curve:P-256']);
      // A request that asks for another name: nothing of it but its key may count.
      final request = await openssl([
        'req',
        '-new',
        '-key',
        '/dev/stdin',
        '-subj',
        '/CN=evil.example',
        '-addext',
        'subjectAltName=DNS:evil.example',
      ], input: key);
      final homeserverRequest = await certificateRequest();
      final requests = '$request$homeserverRequest';
      final feed = SecretsFile(
        kdbx,
        cli: cli,
      ).stopLines(host: 'checkout', project: 'checkout', needs: ['forge-certificate']);
      final before = home.listSync(recursive: true).map((each) => each.path).toSet();

      final signed = await run(feed, 'm', environment: {'request': requests});
      expect(signed.exitCode, 0, reason: '${signed.stderr}');
      expect(home.listSync(recursive: true).map((each) => each.path).toSet(), before, reason: 'no file of it here');
      final line = '${signed.stdout}'.trim();
      expect(line, startsWith('forge-certificate '));
      final pems = utf8.decode(base64Decode(line.split(' ').last));
      final blocks = RegExp(r'-----BEGIN CERTIFICATE-----[^-]+-----END CERTIFICATE-----')
          .allMatches(pems)
          .map((m) => m.group(0)!)
          .toList();
      expect(blocks, hasLength(3), reason: 'the forge\'s certificate, the homeserver\'s, then the CA\'s');
      await File(path.join(home.path, 'ca.pem')).writeAsString('${blocks.last}\n');
      await File(path.join(home.path, 'forge.pem')).writeAsString('${blocks.first}\n');
      expect(await openssl(['verify', '-no-CApath', '-no-CAstore', '-CAfile', 'ca.pem', 'forge.pem']), contains('OK'));
      final text = await openssl([
        'x509',
        '-in',
        'forge.pem',
        '-noout',
        '-subject',
        '-ext',
        'subjectAltName,basicConstraints',
      ]);
      expect(text, contains('CN=forge.checkout.porelo.internal'));
      expect(text, contains('DNS:forge.checkout.porelo.internal, IP Address:10.73.0.1'));
      expect(text, contains('CA:FALSE'));
      expect(text, isNot(contains('evil')), reason: 'nothing of the request but its key');
      expect(
        await openssl(['x509', '-in', 'forge.pem', '-noout', '-pubkey']),
        await openssl(['pkey', '-pubout'], input: key),
        reason: 'for the host\'s own key',
      );
      expect(
        await openssl(['x509', '-in', 'ca.pem', '-noout', '-ext', 'nameConstraints']),
        contains('DNS:checkout.porelo.internal'),
      );
      for (final (i, name, csr) in [(0, 'forge', request), (1, 'matrix', homeserverRequest)]) {
        final pem = blocks[i];
        final text = await openssl([
          'x509',
          '-noout',
          '-subject',
          '-ext',
          'subjectAltName,basicConstraints,extendedKeyUsage',
        ], input: pem);
        expect(text, contains('CN=$name.checkout.porelo.internal'));
        expect(text, contains('DNS:$name.checkout.porelo.internal, IP Address:10.73.0.1'));
        expect(text, contains('Basic Constraints: critical\n    CA:FALSE'));
        expect(text, contains('TLS Web Server Authentication'));
        expect(text, isNot(contains('evil.example')));
        expect(
          await openssl(['x509', '-noout', '-pubkey'], input: pem),
          await openssl(['req', '-noout', '-pubkey'], input: csr),
        );
        final dates = (await openssl([
          'x509',
          '-noout',
          '-dates',
          '-dateopt',
          'iso_8601',
        ], input: pem)).trim().split('\n');
        DateTime instant(String line) =>
            DateTime.parse(line.substring(line.indexOf('=') + 1).replaceFirst(' GMT', 'Z'));
        expect(instant(dates.last).difference(instant(dates.first)), const Duration(days: 365));
        final certFile = await File(path.join(home.path, '$name.pem')).writeAsString('$pem\n');
        expect(
          await openssl([
            'verify',
            '-no-CApath',
            '-no-CAstore',
            '-CAfile',
            'ca.pem',
            '-purpose',
            'sslserver',
            certFile.path,
          ]),
          contains('OK'),
        );
      }

      // The CA's certificate, public, where the stop's terminal named a file for it; never its key.
      final caout = path.join(home.path, 'ca-out.pem');
      final written = await run(feed, 'm', environment: {'request': requests, 'caout': caout});
      expect(written.exitCode, 0, reason: '${written.stderr}');
      final kept = await File(caout).readAsString();
      expect(kept.trim(), blocks.last.trim());
      expect(kept, isNot(contains('PRIVATE KEY')));

      // Reusing this host's CA keeps its forge trusted without another import.
      final again = await run(feed, 'm', environment: {'request': requests});
      expect(again.exitCode, 0, reason: '${again.stderr}');
      final second = utf8.decode(base64Decode('${again.stdout}'.trim().split(' ').last));
      expect(second, contains(blocks.last), reason: 'one lasting CA');

      final none = await run(feed, 'm');
      expect(none.exitCode, isNot(0), reason: 'no request, nothing signed');
      expect('${none.stdout}', isEmpty);
    }, skip: skip ?? (File('/usr/bin/openssl').existsSync() ? null : 'needs /usr/bin/openssl'));

    test('a wrong master password writes nothing and fails', () async {
      final kdbx = path.join(home.path, 'secrets.kdbx');
      final out = path.join(home.path, 'checkout.pub');
      expect(
        (await run(
          SecretsFile(
            kdbx,
            cli: cli,
          ).prepareHost(host: 'checkout', project: 'checkout', create: true, publicKeyOut: out),
          'right',
          twice: true,
        )).exitCode,
        0,
      );
      await File(out).delete();

      final result = await run(
        SecretsFile(kdbx, cli: cli).prepareHost(host: 'other', project: 'other', create: false, publicKeyOut: out),
        'wrong',
      );

      expect(result.exitCode, isNot(0));
      expect(await File(out).exists(), isFalse, reason: 'no public half without the file opened');
    }, skip: skip);
  });
}
