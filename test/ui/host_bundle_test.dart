import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/host_dialog.dart';
import 'package:porelo_frontend/src/ui/wizard.dart';
import 'package:porelo_host/porelo_host.dart';

import '../features/support/world.dart';
import '../support/host_process.dart';

Future<String> _git(Directory directory, List<String> arguments) async {
  final result = await Process.run(
    'git',
    arguments,
    workingDirectory: directory.path,
    environment: {'GIT_CONFIG_GLOBAL': '/dev/null', 'GIT_CONFIG_NOSYSTEM': '1'},
  );
  expect(result.exitCode, 0, reason: 'git $arguments: ${result.stderr}');
  return '${result.stdout}'.trim();
}

class _Following extends FakeBackend {
  _Following(this.records) : super(const []);
  final List<Followed> records;
  @override
  Future<List<Followed>> following() async => records;
}

class _Secrets implements SecretStore {
  final _values = <String, String>{};
  @override
  Future<String?> read(String name) async => _values[name];
  @override
  Future<void> write(String name, String value) async {
    _values[name] = value;
  }

  @override
  Future<void> remove(String name) async {
    _values.remove(name);
  }

  @override
  Future<void> close() async {}
}

void main() {
  late Directory scratch;
  late Directory source;
  late Directory folder;
  late String verified;
  late String tip;
  late Settings settings;
  late Machines machines;
  late HostRuns runs;
  late List<List<String>> starts;

  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('project-bundle-test-');
    source = await Directory(path.join(scratch.path, 'own source with spaces')).create();
    folder = await Directory(path.join(scratch.path, 'drive')).create();
    await _git(source, ['init', '--initial-branch=main']);
    await _git(source, ['config', 'user.email', 'fixture@example.invalid']);
    await _git(source, ['config', 'user.name', 'Fixture']);
    // The daemon verified the commit by its signature, so the fixture signs it as a project's commit is.
    for (final name in ['signer', 'other']) {
      final made = await Process.run('ssh-keygen', [
        '-q',
        '-t',
        'ed25519',
        '-N',
        '',
        '-C',
        name,
        '-f',
        path.join(scratch.path, name),
      ]);
      expect(made.exitCode, 0, reason: 'ssh-keygen: ${made.stderr}');
    }
    await _git(source, ['config', 'gpg.format', 'ssh']);
    await _git(source, ['config', 'user.signingkey', path.join(scratch.path, 'signer')]);
    await _git(source, ['config', 'commit.gpgsign', 'true']);
    await File(path.join(source.path, 'project.yml')).writeAsString('name: demo\n');
    await _git(source, ['add', 'project.yml']);
    await _git(source, ['commit', '-m', 'Verified project']);
    verified = await _git(source, ['rev-parse', 'HEAD']);
    await File(path.join(source.path, 'project.yml')).writeAsString('name: another\n');
    await _git(source, ['commit', '-am', 'Unverified tip']);
    tip = await _git(source, ['rev-parse', 'HEAD']);
    await File(path.join(scratch.path, 'signer.pub')).copy(path.join(scratch.path, 'signing.pub'));
    await File(path.join(scratch.path, 'identity')).writeAsString('invented key fixture');
    starts = [];
    settings = Settings(MemorySettingsStore());
  });

  tearDown(() async {
    runs.dispose();
    machines.dispose();
    settings.dispose();
    await scratch.delete(recursive: true);
  });

  /// Puts [value] into [field] as a choice would, outside the test's clock, so the check it starts runs its program.
  Future<void> choose(WidgetTester tester, String value, {String field = 'host-signing-key'}) async {
    final widget = tester.widget<TextField>(find.byKey(Key(field)));
    await tester.runAsync(() async => widget.controller!.text = value);
    await tester.pump();
  }

  /// Lets [field]'s check, which runs git or ssh-keygen, finish, until the field shows an answer.
  Future<void> answered(WidgetTester tester, {String field = 'host-signing-key'}) async {
    for (var waited = 0; waited < 300; waited++) {
      final shown =
          find.byKey(Key('$field-ok')).evaluate().isNotEmpty || find.byKey(Key('$field-refused')).evaluate().isNotEmpty;
      if (shown) return;
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    fail('$field showed no answer within 15 seconds');
  }

  Future<void> open(
    WidgetTester tester, {
    String? commit,
    String? url,
    bool chooseFolder = true,
    String? signingKey,
    List<String> signers = const [],
  }) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (chooseFolder) await settings.rememberTresorFolder('demo', folder.path);
    final backend = _Following([
      Followed(name: 'another', url: '/unreadable-other-project', commit: tip),
      Followed(name: 'demo', url: url ?? source.path, commit: commit ?? verified, signers: signers),
    ]);
    machines = Machines(settings, reach: (_) => backend, tunnels: FakeTunnels());
    runs = HostRuns(machines);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(
            openSecretsFile: _secretsOpened,
            project: 'demo',
            machines: machines,
            settings: settings,
            hostRuns: runs,
            secretStore: _Secrets(),
            checkKey: (_, _) async => HostProcess()..end(0),
            hostFiles: (store) => HostFiles(
              store,
              gitEnvironment: const {
                'GIT_TERMINAL_PROMPT': '0',
                'GIT_CONFIG_GLOBAL': '/dev/null',
                'GIT_CONFIG_NOSYSTEM': '1',
              },
            ),
            debug: false,
            start: (_, arguments) async {
              starts.add(List.of(arguments));
              final process = HostProcess();
              process.end(65);
              return process;
            },
          ),
        ),
      ),
    );
    await World.settle(tester);
    await tester.enterText(find.byKey(const Key('host-scaleway-project')), 'provider');
    await tester.pump();
    await tester.tap(find.byKey(const Key('wizard-next')));
    await World.settle(tester);
    await tester.enterText(find.byKey(const Key('host-tresor')), 'drive');
    if (chooseFolder) {
      final oldRepository = find.byKey(const Key('host-repository'));
      if (oldRepository.evaluate().isNotEmpty) await tester.enterText(oldRepository, '/wrong-stored-repository');
      // Outside the test's clock, so the check the field starts finishes and removes its scratch work.
      if (signingKey != '') await choose(tester, signingKey ?? path.join(scratch.path, 'signing.pub'));
    }
    await tester.pump();
  }

  /// Leaves the drive step: the bundle is made, and its signer checked, before the next step opens.
  Future<void> drive(WidgetTester tester) async {
    final next = tester.widget<FilledButton>(find.byKey(const Key('wizard-next'))).onPressed!;
    await tester.runAsync(() async {
      await Function.apply(next, const []);
    });
    await World.settle(tester);
  }

  Future<void> put(WidgetTester tester) async {
    await drive(tester);
    if (find.byKey(const Key('host-identity')).evaluate().isEmpty) return;
    await tester.enterText(find.byKey(const Key('host-identity')), path.join(scratch.path, 'identity'));
    await tester.enterText(find.byKey(const Key('host-public-key')), path.join(scratch.path, 'signing.pub'));
    await tester.pump();
    final wizard = tester.widget<Wizard>(find.byType(Wizard));
    await tester.runAsync(wizard.actionSteps.single.run);
    await World.settle(tester);
  }

  // Harm: renting with the upstream tip or another project runs code the daemon never verified.
  testWidgets('the published bundle contains exactly the followed commit as main and HEAD', (tester) async {
    await open(tester);
    await put(tester);
    final bundle = File(path.join(folder.path, 'porelo-host', 'demo.bundle'));
    expect(bundle.existsSync(), isTrue, reason: 'setup must publish the selected project bundle before renting');
    await tester.runAsync(() async {
      final heads = await _git(source, ['bundle', 'list-heads', bundle.path]);
      expect(heads.split('\n').toSet(), {'$verified HEAD', '$verified refs/heads/main'});
      final clone = Directory(path.join(scratch.path, 'host-follow'));
      await _git(scratch, ['clone', '--', bundle.path, clone.path]);
      expect(await _git(clone, ['rev-parse', 'HEAD']), verified);
      expect(await File(path.join(clone.path, 'project.yml')).readAsString(), 'name: demo\n');
      final rejected = await Process.run(
        'git',
        ['cat-file', '-e', tip],
        workingDirectory: clone.path,
        environment: {'GIT_CONFIG_GLOBAL': '/dev/null', 'GIT_CONFIG_NOSYSTEM': '1'},
      );
      expect(rejected.exitCode, isNot(0), reason: 'unverified history must not leave this computer');
      final yaml = await File(path.join(bundle.parent.path, 'machine.yml')).readAsString();
      expect(yaml, contains('url: "/srv/porelo-host/drive/porelo-host/demo.bundle"'));
    });
    expect(starts, hasLength(1));
  });

  // Harm: a daemon-made local bundle must remain usable as the source of a trusted host follow.
  testWidgets('a followed local bundle publishes the verified commit with a remote HEAD', (tester) async {
    final input = File(path.join(scratch.path, 'source.bundle'));
    await tester.runAsync(() => _git(source, ['bundle', 'create', input.path, 'HEAD', 'main']));
    await open(tester, url: input.path);
    await put(tester);
    final output = File(path.join(folder.path, 'porelo-host', 'demo.bundle'));
    expect(output.existsSync(), isTrue, reason: 'the daemon supplied bundle must be readable before renting');
    await tester.runAsync(() async {
      expect((await _git(source, ['bundle', 'list-heads', output.path])).split('\n').toSet(), {
        '$verified HEAD',
        '$verified refs/heads/main',
      });
    });
    expect(starts, hasLength(1));
  });

  // Harm: an outdated bundle leaves a resumed server running the wrong verified project revision.
  testWidgets('publication replaces an existing regular bundle with the verified revision', (tester) async {
    final root = Directory(path.join(folder.path, 'porelo-host'))..createSync();
    final output = File(path.join(root.path, 'demo.bundle'))..writeAsStringSync('previous bundle');
    await open(tester);
    await put(tester);
    expect(
      String.fromCharCodes(output.readAsBytesSync().take(15)).startsWith('previous bundle'),
      isFalse,
      reason: 'publication must replace the previous bundle',
    );
    await tester.runAsync(() async {
      expect((await _git(source, ['bundle', 'list-heads', output.path])).split('\n').toSet(), {
        '$verified HEAD',
        '$verified refs/heads/main',
      });
    });
    expect(root.listSync().map((file) => path.basename(file.path)).toSet(), {
      'demo.bundle',
      'machine.yml',
    }, reason: 'no staging directory may remain after publication, and no host key: the secrets file keeps it');
  });

  String fingerprint(String name) =>
      HostFiles.signingFingerprint(File(path.join(scratch.path, '$name.pub')).readAsStringSync());

  // Harm: a check mark beside a key it was not given for lets the person rent with a key that did not sign the commit.
  testWidgets('the signing key is checked as soon as it changes, and its answer goes with it', (tester) async {
    await open(tester, signingKey: '');
    await choose(tester, path.join(scratch.path, 'other.pub'));
    await answered(tester);
    expect(find.byKey(const Key('host-signing-key-refused')), findsOneWidget, reason: 'refused before Next');
    expect(find.textContaining('not by ${fingerprint('other')}'), findsOneWidget);
    expect(find.byKey(const Key('host-signing-key-ok')), findsNothing);

    // Half typed: not yet a key to check, and still not the key that was refused.
    await choose(tester, path.join(scratch.path, 'sign'));
    expect(find.byKey(const Key('host-signing-key-refused')), findsNothing, reason: 'no refusal beside another value');
    expect(find.textContaining('not by'), findsNothing);

    await choose(tester, path.join(scratch.path, 'signing.pub'));
    expect(find.byKey(const Key('host-signing-key-refused')), findsNothing, reason: 'the old refusal goes at once');
    expect(find.textContaining('not by'), findsNothing);
    await answered(tester);
    expect(find.byKey(const Key('host-signing-key-ok')), findsOneWidget, reason: 'the key that signed is said to');

    await choose(tester, path.join(scratch.path, 'sign'));
    expect(find.byKey(const Key('host-signing-key-ok')), findsNothing, reason: 'no check mark beside a half typed key');
    await choose(tester, path.join(scratch.path, 'signing.pub'));
    await answered(tester);

    await choose(tester, path.join(scratch.path, 'other.pub'));
    expect(find.byKey(const Key('host-signing-key-ok')), findsNothing, reason: 'no check mark beside a changed key');
    await answered(tester);
    expect(find.byKey(const Key('host-signing-key-refused')), findsOneWidget);
    expect(find.byKey(const Key('host-identity')), findsNothing, reason: 'nothing went on to the next step');
  });

  // Harm: a check of the field outliving Next's own check left the whole dialog busy, every field shut.
  testWidgets('a key chosen while Next checks leaves the dialog free once both answered', (tester) async {
    await open(tester, signingKey: '');
    await choose(tester, path.join(scratch.path, 'other.pub'));
    await answered(tester);
    final pressed = tester.widget<FilledButton>(find.byKey(const Key('wizard-next'))).onPressed!;
    final field = tester.widget<TextField>(find.byKey(const Key('host-signing-key'))).controller!;
    await tester.runAsync(() async {
      // Next's check of the refused key, then at once a check of another key from the field.
      pressed();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      field.text = path.join(scratch.path, 'signing.pub');
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byKey(const Key('host-signing-key'))).enabled,
      isTrue,
      reason: 'the dialog is free again once both checks answered',
    );
  });

  // Harm: an earlier refusal left on screen after the key passed reads as if the key the person chose were refused.
  testWidgets('what an earlier step said goes once the key passes and Next goes on', (tester) async {
    await open(tester);
    await answered(tester);
    expect(find.byKey(const Key('host-signing-key-ok')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('host-key-name')), 'not/a name');
    await tester.ensureVisible(find.text('Choose a file for this vault entry'));
    await tester.tap(find.text('Choose a file for this vault entry'));
    await tester.pump();
    expect(find.textContaining('A name must not'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('host-key-name')), '');
    await tester.pump();
    await drive(tester);
    expect(find.byKey(const Key('host-identity')), findsOneWidget);
    expect(find.textContaining('A name must not'), findsNothing, reason: 'the earlier message goes with Next');
  });

  // Harm: a private key chosen as the signing key would be read whole into the interface by Next's check.
  testWidgets('a private key in the signing key field is refused before anything reads it', (tester) async {
    await open(tester, signingKey: path.join(scratch.path, 'signer'));
    expect(find.textContaining('is not a public key (.pub)'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('wizard-next'))).onPressed, isNull);
  });

  // Harm: a late answer about the key the person left would stand beside the key they chose.
  testWidgets('of two checks running at once, the answer about the key in the field stands', (tester) async {
    await open(tester, signingKey: '');
    await choose(tester, path.join(scratch.path, 'other.pub'));
    await choose(tester, path.join(scratch.path, 'signing.pub'));
    await answered(tester);
    // Both checks have had time to answer.
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await tester.pump();
    expect(find.byKey(const Key('host-signing-key-ok')), findsOneWidget);
    expect(find.byKey(const Key('host-signing-key-refused')), findsNothing, reason: 'the left key answers nothing');
    expect(find.textContaining('not by'), findsNothing);
  });

  group('with a home of its own', () {
    late Desk previous;
    late Directory ssh;
    setUp(() {
      previous = desk;
      // This system's desk, so its separator is the one the files listed in ~/.ssh come back with.
      desk = Desk.of(Platform.operatingSystem, {'HOME': scratch.path, 'USERPROFILE': scratch.path});
      ssh = Directory(path.join(scratch.path, '.ssh'))..createSync();
    });
    tearDown(() => desk = previous);

    /// On Windows no server is set up yet: Start refuses, saying why, and nothing is rented.
    bool refusedOnWindows() {
      if (!Platform.isWindows) return false;
      expect(starts, isEmpty);
      expect(find.textContaining('opens only on Linux so far'), findsOneWidget);
      return true;
    }

    // Harm: the host refuses machine.yml only after a server is rented and set up for about 20 minutes.
    testWidgets('a signing key that did not sign the commit stops the drive, naming both keys', (tester) async {
      await open(tester, signingKey: path.join(scratch.path, 'other.pub'));
      await drive(tester);
      expect(find.byKey(const Key('host-identity')), findsNothing, reason: 'the drive step must stop');
      final refusal = find.textContaining('signed by ${fingerprint('signer')}, not by ${fingerprint('other')}');
      expect(refusal, findsOneWidget);
      expect(find.textContaining('may be swapped'), findsNothing, reason: 'the login key is another one');
      expect(File(path.join(folder.path, 'porelo-host', 'demo.bundle')).existsSync(), isFalse);
      // The corrected key is checked again rather than the refused bundle taken.
      await choose(tester, path.join(scratch.path, 'signing.pub'));
      await tester.pump();
      await put(tester);
      if (refusedOnWindows()) return;
      expect(starts, hasLength(1), reason: 'the key that signed the commit must go on to renting');
      final yaml = File(path.join(folder.path, 'porelo-host', 'machine.yml')).readAsStringSync();
      expect(yaml, contains('signed_by: "${fingerprint('signer')}"'));
    });

    /// Leaves the drive with the key that signed, and waits on *Your ssh keys*.
    Future<void> toTheSshKeys(WidgetTester tester) async {
      await open(tester);
      await drive(tester);
      expect(find.byKey(const Key('host-identity')), findsOneWidget, reason: 'the signing key passes the drive');
    }

    /// Presses Next and lets the check it starts finish.
    Future<void> next(WidgetTester tester) async {
      final pressed = tester.widget<FilledButton>(find.byKey(const Key('wizard-next'))).onPressed!;
      await tester.runAsync(() async {
        pressed();
        for (var waited = 0; waited < 100; waited++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });
      await World.settle(tester);
    }

    // Harm: a public key that does not belong to the login key rents a server this computer cannot sign in to.
    testWidgets('the public ssh key follows its private one and a key of another pair is refused', (tester) async {
      await toTheSshKeys(tester);
      // The field holds a public key from before, as a kept run leaves it.
      await choose(tester, path.join(scratch.path, 'signer.pub'), field: 'host-public-key');

      await choose(tester, path.join(scratch.path, 'other'), field: 'host-identity');
      expect(
        tester.widget<TextField>(find.byKey(const Key('host-public-key'))).controller!.text,
        path.join(scratch.path, 'other.pub'),
        reason: 'the public key follows the private one over the earlier value',
      );
      await answered(tester, field: 'host-public-key');
      expect(find.byKey(const Key('host-public-key-ok')), findsOneWidget, reason: 'the pair belongs together');

      await choose(tester, path.join(scratch.path, 'signer.pub'), field: 'host-public-key');
      expect(find.byKey(const Key('host-public-key-ok')), findsNothing, reason: 'no check mark beside a changed key');
      await answered(tester, field: 'host-public-key');
      expect(find.byKey(const Key('host-public-key-refused')), findsOneWidget);
      expect(
        find.textContaining(
          '${fingerprint('signer')} does not belong to the private key, whose key is ${fingerprint('other')}',
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('wizard-next'))).onPressed,
        isNull,
        reason: 'a pair that does not belong together goes no further',
      );
    });

    // Harm: ssh-keygen reads the .pub beside a private key in its stead, so a wrong .pub would pass as its own pair.
    testWidgets('a .pub beside the private key that belongs to another pair is refused', (tester) async {
      File(path.join(scratch.path, 'other')).copySync(path.join(ssh.path, 'login'));
      File(path.join(scratch.path, 'signer.pub')).copySync(path.join(ssh.path, 'login.pub'));
      await toTheSshKeys(tester);
      await choose(tester, path.join(ssh.path, 'login'), field: 'host-identity');
      expect(
        tester.widget<TextField>(find.byKey(const Key('host-public-key'))).controller!.text,
        path.join(ssh.path, 'login.pub'),
      );
      await answered(tester, field: 'host-public-key');
      expect(find.byKey(const Key('host-public-key-refused')), findsOneWidget, reason: 'the key itself is asked');
      expect(find.textContaining('whose key is ${fingerprint('other')}'), findsOneWidget);
    });

    // Harm: a private key named relative to this program's folder pointed the link nowhere, and the check said nothing.
    testWidgets('a private key given by a relative path is asked about too', (tester) async {
      File(path.join(scratch.path, 'other')).copySync(path.join(ssh.path, 'login'));
      File(path.join(scratch.path, 'signer.pub')).copySync(path.join(ssh.path, 'login.pub'));
      final previous = Directory.current;
      Directory.current = ssh;
      addTearDown(() => Directory.current = previous);
      await toTheSshKeys(tester);
      await choose(tester, 'login', field: 'host-identity');
      expect(find.byKey(const Key('host-public-key-refused')), findsOneWidget, reason: 'the key itself is asked');
    });

    // Harm: the start writing out ~/ would put the private key's .pub back over the public key the person chose.
    testWidgets('the public key chosen after a ~/ private key is the one the start takes', (tester) async {
      File(path.join(scratch.path, 'other')).copySync(path.join(ssh.path, 'login'));
      File(path.join(scratch.path, 'other.pub')).copySync(path.join(ssh.path, 'login.pub'));
      File(path.join(scratch.path, 'other.pub')).copySync(path.join(scratch.path, 'chosen.pub'));
      await toTheSshKeys(tester);
      await choose(tester, '~/.ssh/login', field: 'host-identity');
      await choose(tester, path.join(scratch.path, 'chosen.pub'), field: 'host-public-key');
      await answered(tester, field: 'host-public-key');
      expect(find.byKey(const Key('host-public-key-ok')), findsOneWidget);
      await next(tester);
      final wizard = tester.widget<Wizard>(find.byType(Wizard));
      await tester.runAsync(wizard.actionSteps.single.run);
      await World.settle(tester);
      if (refusedOnWindows()) return;
      expect(starts, hasLength(1));
      final arguments = starts.single;
      expect(arguments[arguments.indexOf('--public-key') + 1], path.join(scratch.path, 'chosen.pub'));
    });

    // Harm: a .pub changed on disk after the field answered would let a pair of two keys through Next.
    testWidgets('Next asks about the pair itself before it goes on', (tester) async {
      await toTheSshKeys(tester);
      File(path.join(scratch.path, 'other.pub')).copySync(path.join(ssh.path, 'login.pub'));
      File(path.join(scratch.path, 'other')).copySync(path.join(ssh.path, 'login'));
      await choose(tester, path.join(ssh.path, 'login'), field: 'host-identity');
      expect(find.byKey(const Key('host-public-key-ok')), findsOneWidget, reason: 'the pair belongs together');
      File(path.join(scratch.path, 'signer.pub')).copySync(path.join(ssh.path, 'login.pub'));
      await next(tester);
      expect(find.byKey(const Key('host-identity')), findsOneWidget, reason: 'Next stays on the keys');
      expect(find.textContaining('does not belong to the private key'), findsOneWidget);
    });

    // Harm: a key changed after the drive passed would write its fingerprint beside a bundle it never signed.
    testWidgets('a signing key changed after the drive passed is checked again', (tester) async {
      await open(tester);
      await drive(tester);
      expect(find.byKey(const Key('host-identity')), findsOneWidget, reason: 'the signing key passes the drive');
      await tester.tap(find.byKey(const Key('wizard-back')));
      await World.settle(tester);
      await choose(tester, path.join(scratch.path, 'other.pub'));
      await tester.pump();
      await drive(tester);
      expect(find.byKey(const Key('host-identity')), findsNothing, reason: 'the changed key must be checked again');
      expect(find.textContaining('not by ${fingerprint('other')}'), findsOneWidget);
    });

    // Harm: the server login key in the signing field went unnoticed until the rented host refused it.
    testWidgets('the login key in the signing field is said to look swapped', (tester) async {
      File(path.join(scratch.path, 'other.pub')).copySync(path.join(ssh.path, 'id_ed25519.pub'));
      await open(tester, signingKey: path.join(ssh.path, 'id_ed25519.pub'));
      await drive(tester);
      expect(find.byKey(const Key('host-identity')), findsNothing);
      expect(find.textContaining('the two key fields may be swapped'), findsOneWidget);
    });

    // Harm: the field opens on the person's ssh key, which is rarely the key the project's commits are signed with.
    testWidgets("the signing field opens on a key the project's machine pins", (tester) async {
      File(path.join(scratch.path, 'other.pub')).copySync(path.join(ssh.path, 'a.pub'));
      File(path.join(scratch.path, 'signer.pub')).copySync(path.join(ssh.path, 'b.pub'));
      await open(tester, signingKey: '', signers: [fingerprint('signer')]);
      expect(
        tester.widget<TextField>(find.byKey(const Key('host-signing-key'))).controller!.text,
        path.join(ssh.path, 'b.pub'),
      );
      await put(tester);
      if (refusedOnWindows()) return;
      expect(starts, hasLength(1));
    });

    // Harm: a pin replacing the key the person chose and kept on an earlier run.
    testWidgets('a signing key kept from an earlier run is not replaced by a pinned one', (tester) async {
      File(path.join(scratch.path, 'signer.pub')).copySync(path.join(ssh.path, 'b.pub'));
      await settings.rememberHostUp(
        'demo',
        HostUpRecord(
          scalewayProject: 'provider',
          account: 'porelo',
          tresor: 'drive',
          folder: folder.path,
          repository: '',
          signingKey: path.join(scratch.path, 'signing.pub'),
          identity: path.join(scratch.path, 'identity'),
          publicKey: path.join(scratch.path, 'signing.pub'),
          collection: '',
          collectionSha256: '',
          vpnPeerPublicKey: '',
          vpnPeerAddress: '',
          vpnHostPublicKey: '',
        ),
      );
      await open(tester, signingKey: '', signers: [fingerprint('signer')]);
      expect(
        tester.widget<TextField>(find.byKey(const Key('host-signing-key'))).controller!.text,
        path.join(scratch.path, 'signing.pub'),
      );
    });
  });

  for (final refusal in ['missing commit', 'unreadable source', 'option source', 'invalid commit']) {
    // Harm: failed source validation rents a server anyway or leaves cloned project history behind.
    testWidgets('$refusal refuses before renting and removes scratch work', (tester) async {
      // Only this code's own scratch directories: other suites create theirs in the same place at once.
      Set<String> scratchWork() => Directory.systemTemp
          .listSync()
          .map((entry) => entry.path)
          .where((name) => path.basename(name).startsWith('.porelo-writing-'))
          .toSet();
      final before = scratchWork();
      await open(
        tester,
        commit: refusal == 'missing commit'
            ? '0' * 40
            : refusal == 'invalid commit'
            ? '--help'
            : verified,
        url: refusal == 'unreadable source'
            ? path.join(scratch.path, 'absent')
            : refusal == 'option source'
            ? '--upload-pack=touch'
            : source.path,
      );
      // The field's own check of the key, which also prepares a bundle, has answered and cleared its scratch work.
      await answered(tester);
      // The action checks every step again even if navigation has been bypassed.
      final wizard = tester.widget<Wizard>(find.byType(Wizard));
      // Reach the key fields when the drive itself has already accepted the source.
      if (tester.widget<FilledButton>(find.byKey(const Key('wizard-next'))).onPressed != null) {
        await put(tester);
      } else {
        await tester.runAsync(wizard.actionSteps.single.run);
      }
      expect(starts, isEmpty, reason: 'unreadable or invalid followed sources must never rent a host');
      // Other test files prepare bundles in the same temporary folder at the same time; what this test left
      // stays, while theirs goes once their work ends.
      var left = scratchWork().difference(before);
      for (var waited = 0; left.isNotEmpty && waited < 100; waited++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        left = left.intersection(scratchWork());
      }
      expect(left, isEmpty, reason: 'failed preparation must remove its private scratch directory');
      expect(File(path.join(folder.path, 'porelo-host', 'demo.bundle')).existsSync(), isFalse);
    });
  }

  for (final type in ['symlink', 'directory']) {
    // Harm: publication through an existing link or directory damages unrelated local files.
    testWidgets('bundle publication refuses a $type and leaves outside files untouched', (tester) async {
      final outside = Directory(path.join(scratch.path, 'outside'))..createSync();
      final sentinel = File(path.join(outside.path, 'demo.bundle'))..writeAsStringSync('keep');
      final root = Directory(path.join(folder.path, 'porelo-host'));
      if (type == 'root symlink') {
        Link(root.path).createSync(outside.path);
      } else {
        root.createSync();
        final target = path.join(root.path, 'demo.bundle');
        if (type == 'symlink') {
          Link(target).createSync(sentinel.path);
        } else {
          Directory(target).createSync();
        }
      }
      await open(tester);
      await put(tester);
      expect(starts, isEmpty, reason: 'unsafe bundle destinations must refuse before renting');
      expect(sentinel.readAsStringSync(), 'keep');
      expect(outside.listSync().map((file) => path.basename(file.path)), ['demo.bundle']);
    });
  }

  for (final chooseFolder in [true, false]) {
    // Harm: an unverified project rents a billing server with no trusted project to run.
    testWidgets('no verified commit blocks the drive step with folder $chooseFolder', (tester) async {
      await open(tester, commit: '', chooseFolder: chooseFolder);
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('wizard-next'))).onPressed,
        isNull,
        reason: 'an unverified project must be refused in the drive step',
      );
      final wizard = tester.widget<Wizard>(find.byType(Wizard));
      await tester.runAsync(wizard.actionSteps.single.run);
      expect(starts, isEmpty);
    });
  }
}

/// Stands in for the secrets file's terminal: the public half of a fixed host key.
Future<String> _secretsOpened({
  required String file,
  required String project,
  String? migrateKeyFrom,
  Map<String, String> keys = const {},
}) => HostFiles.publicKey(base64Encode(List<int>.filled(32, 5)));
