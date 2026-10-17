// Linux only: it runs its stand-ins for ssh as Bash scripts.
@Tags(<String>['linux'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machine_setup.dart';
import 'package:porelo_frontend/src/app/setup_run.dart';

/// Against the real `ssh-keygen`: the pair it makes, and the check that two pasted halves belong
/// together, are only worth as much as the tool that answers them.
void main() {
  late Directory home;
  late MachineSetup setup;

  setUp(() {
    home = Directory.systemTemp.createTempSync('machine-setup-');
    setup = MachineSetup(home: home.path);
  });

  tearDown(() => home.deleteSync(recursive: true));

  int mode(String path) => FileStat.statSync(path).mode & 0x1FF;

  test('a generated pair belongs together and is written owner-only', () async {
    final pair = await setup.generate('porelo build machine');

    expect(pair.publicKey, startsWith('ssh-ed25519 '));
    expect(pair.publicKey, endsWith('porelo build machine'));
    expect(await setup.mismatch(pair), isNull);

    final path = await setup.save(pair, 'porelo-build');

    expect(path, '${home.path}/.ssh/porelo-build');
    expect(mode('${home.path}/.ssh'), 0x1C0, reason: '~/.ssh is not 700');
    expect(mode(path), 0x180, reason: 'the private key is not 600');
    expect(mode('$path.pub'), 0x1A4, reason: 'the public key is not 644');
    expect(File(path).readAsStringSync(), pair.privateKey);
  });

  test("halves of two different pairs are refused before anything is written", () async {
    final one = await setup.generate('one');
    final other = await setup.generate('other');

    final said = await setup.mismatch(KeyPair(privateKey: one.privateKey, publicKey: other.publicKey));

    expect(said, contains('does not belong'));
  });

  test('a comment that differs is still the same key', () async {
    final pair = await setup.generate('as generated');
    final renamed = '${pair.publicKey.split(' ').take(2).join(' ')} renamed by somebody';

    expect(await setup.mismatch(KeyPair(privateKey: pair.privateKey, publicKey: renamed)), isNull);
  });

  test('something that is not a private key says so', () async {
    final pair = await setup.generate('x');

    final said = await setup.mismatch(KeyPair(privateKey: 'not a key', publicKey: pair.publicKey));

    expect(said, contains('cannot be read'));
  });

  test('saving twice is harmless, and another key under that name is never overwritten', () async {
    final pair = await setup.generate('first');
    await setup.save(pair, 'porelo-build');
    await setup.save(pair, 'porelo-build');

    final other = await setup.generate('second');
    await expectLater(setup.save(other, 'porelo-build'), throwsA(isA<MachineSetupFailed>()));
    expect(File('${home.path}/.ssh/porelo-build').readAsStringSync(), pair.privateKey);
  });

  test('a pair never says its private half', () async {
    final pair = await setup.generate('x');

    expect('$pair', isNot(contains('PRIVATE')));
  });

  test('a failed root login says what ssh said', () async {
    final failing = MachineSetup(
      home: home.path,
      run: (command, {input}) async => ProcessResult(0, 255, '', 'root@203.0.113.10: Permission denied (publickey).'),
    );

    expect(await failing.loginAsRoot('203.0.113.10', '/k'), contains('Permission denied'));
  });

  group('the Host entry', () {
    Future<String> add({String alias = 'porelo-build', String user = 'agents'}) =>
        setup.addHostEntry(alias: alias, host: '203.0.113.10', user: user, keyFile: '${home.path}/.ssh/porelo-build');

    String config() => File('${home.path}/.ssh/config').readAsStringSync();

    test('a first entry makes the file owner-only and names the work user and the key', () async {
      await add();

      expect(
        config(),
        'Host porelo-build\n    HostName 203.0.113.10\n    User agents\n'
        '    IdentityFile ${home.path}/.ssh/porelo-build\n    IdentitiesOnly yes\n',
      );
      expect(mode('${home.path}/.ssh/config'), 0x180);
    });

    test("somebody's own entries are kept, a copy is made first, and the entry is appended", () async {
      Directory('${home.path}/.ssh').createSync();
      File('${home.path}/.ssh/config').writeAsStringSync('Host mine\n    User me\n');

      await add();

      expect(config(), startsWith('Host mine\n    User me\n\nHost porelo-build\n'));
      expect(File('${home.path}/.ssh/config.before-porelo-build').readAsStringSync(), 'Host mine\n    User me\n');
    });

    test('adding it twice changes nothing', () async {
      await add();
      final once = config();

      expect(await add(), contains('already has'));
      expect(config(), once);
    });

    test('an entry of that name that says something else is never overwritten', () async {
      await add();

      await expectLater(add(user: 'somebody-else'), throwsA(isA<MachineSetupFailed>()));
      expect(config(), contains('User agents'));
      expect(config(), isNot(contains('somebody-else')));
    });
  });

  test('every exit the setup script promises is said in words', () {
    expect(MachineSetup.whatTheScriptSaid(0), 'The machine is prepared.');
    expect(MachineSetup.whatTheScriptSaid(3), contains('does not know this operating system'));
    expect(MachineSetup.whatTheScriptSaid(4), contains('root'));
    expect(MachineSetup.whatTheScriptSaid(5), contains('not usable'));
    expect(MachineSetup.whatTheScriptSaid(9), contains('9'));
  });

  test('allowing the key names the user in every command and appends it only once', () {
    final script = MachineSetup.authorize('agents', 'ssh-ed25519 AAAA laptop');

    expect(script, contains('-o "\$user" -g "\$user"'));
    expect(script, contains('grep -qxF "\$key"'));
    expect(script, startsWith('set -e'));
  });

  test('a key whose comment holds a quote reaches root exactly as it is', () async {
    // The comment is a machine name somebody typed; "Alice's box" once broke the root script.
    const key = "ssh-ed25519 AAAA Alice's box'; touch /tmp/porelo-pwned; '";
    final lines = MachineSetup.authorize("o'brien", key).split('\n').take(3).join('\n');

    final ran = await Process.run('bash', <String>['-c', '$lines\nprintf "%s\\n" "\$user" "\$key"']);

    expect(ran.exitCode, 0, reason: ran.stderr as String);
    expect(ran.stdout, "o'brien\n$key\n");
  });

  group('what a machine could install', () {
    test('every field is read, and a missing one reads as nothing rather than failing', () {
      final packages = MachineSetup.installableIn(
        '{"packages": ['
        '{"name": "porelo-agent-claude", "kind": "agent", "description": "Claude Code", '
        '"installed": true, "version": "1.0"}, {"name": "porelo-agent-omp"}]}',
      );

      expect(packages.map((each) => each.name), <String>['porelo-agent-claude', 'porelo-agent-omp']);
      expect(packages.first.kind, 'agent');
      expect(packages.first.installed, isTrue);
      expect(packages.first.version, '1.0');
      expect(packages.last.installed, isFalse);
      expect(packages.last.description, isEmpty);
    });

    test('a name that could not be a package never reaches a root command line', () {
      final packages = MachineSetup.installableIn(
        '{"packages": ['
        '{"name": "x\'; rm -rf / #"}, {"name": "Upper"}, {"name": "ok-1.0+b"}]}',
      );

      expect(packages.map((each) => each.name), <String>['ok-1.0+b']);
    });

    // Verbatim what Porelo measured on the Ubuntu VM (e582250): the
    // transport package, found because it declares Provides: porelo-transport.
    test("the script's own answer, as measured on a real machine, is read", () {
      final packages = MachineSetup.installableIn(
        '{"packages":[{"name":"porelo-message-transport-local",'
        '"kind":"transport","description":"Carries agent messages between mailboxes on one machine",'
        '"installed":true,"version":"1.0.0~snapshot.0+local.20260918T100444"}]}',
      );

      expect(packages.single.name, 'porelo-message-transport-local');
      expect(packages.single.kind, 'transport');
      expect(packages.single.installed, isTrue);
      expect(packages.single.version, '1.0.0~snapshot.0+local.20260918T100444');
    });

    test('a shape this build does not read is said, not guessed at', () {
      expect(() => MachineSetup.installableIn('{"items": []}'), throwsA(isA<MachineSetupFailed>()));
    });

    test('the choice is carried into both showing and running, the same way', () {
      expect(
        MachineSetup.show('agents', <String>['porelo-agent-claude']),
        contains("--user agents --with porelo-agent-claude --show"),
      );
      expect(
        MachineSetup.prepare('agents', <String>[
          'porelo-agent-claude',
        ], digest: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'),
        endsWith("\nbash /root/porelo-setup.sh --user agents --with porelo-agent-claude\n"),
      );
    });

    test('only the script shown runs: its SHA-256 is checked first', () {
      final shown = MachineSetup.digestIn(
        'The script shown has the SHA-256 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.\nuseradd agents',
      );
      expect(shown, 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
      final script = MachineSetup.prepare('agents', <String>[], digest: shown!);
      expect(
        script,
        startsWith(
          "printf '%s  %s\\n' 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' /root/porelo-setup.sh | sha256sum -c --status",
        ),
      );
      expect(script, contains('exit ${MachineSetup.notTheScriptShown}'));
      expect(() => MachineSetup.prepare('agents', <String>[], digest: ''), throwsA(isA<MachineSetupFailed>()));
    });

    test('nothing but a user name and package names reaches root, whatever a kept draft held', () {
      expect(() => MachineSetup.show("agents'; rm -rf / #", <String>[]), throwsA(isA<MachineSetupFailed>()));
      expect(() => MachineSetup.show('agents', <String>["x'; id #"]), throwsA(isA<MachineSetupFailed>()));
      expect(
        SetupRun.fromStored(<String, Object?>{'name': 'box', 'workUser': "agents'; id #"}, setup: MachineSetup()),
        isNull,
      );
    });
  });

  group('the keys already in ~/.ssh', () {
    test('every private key is offered, and nothing that is not one', () async {
      final ssh = Directory('${home.path}/.ssh')..createSync();
      await setup.save(await setup.generate('a'), 'id_ed25519');
      File('${ssh.path}/lonely').writeAsStringSync('-----BEGIN OPENSSH PRIVATE KEY-----\nx\n');
      File('${ssh.path}/known_hosts').writeAsStringSync('host ssh-ed25519 AAAA\n');
      File('${ssh.path}/config').writeAsStringSync('Host x\n');
      File('${ssh.path}/authorized_keys').writeAsStringSync('ssh-ed25519 AAAA\n');

      expect(setup.sshKeys().map((path) => path.split('/').last), <String>['id_ed25519', 'lonely']);
    });

    test('a key with a passphrase is refused, never asked about', () async {
      final ssh = Directory('${home.path}/.ssh')..createSync();
      final made = await Process.run('ssh-keygen', <String>[
        '-q',
        '-t',
        'ed25519',
        '-N',
        'secret',
        '-f',
        '${ssh.path}/locked',
      ]);
      expect(made.exitCode, 0);

      await expectLater(
        setup.publicKeyOf('${ssh.path}/locked').timeout(const Duration(seconds: 10)),
        throwsA(isA<MachineSetupFailed>()),
      );
    });
  });
}
