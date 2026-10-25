import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/host_dialog.dart';
import 'package:porelo_frontend/src/ui/wizard.dart';
import 'package:porelo_host/porelo_host.dart';

import '../features/support/world.dart';
import '../support/host_process.dart';

const _signing = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAABAgMEBQYHCAkKCwwNDg8QERITFBUWFxgZGhscHR4f fixture';

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
    await _git(source, ['config', 'commit.gpgsign', 'false']);
    await File(path.join(source.path, 'project.yml')).writeAsString('name: demo\n');
    await _git(source, ['add', 'project.yml']);
    await _git(source, ['commit', '-m', 'Verified project']);
    verified = await _git(source, ['rev-parse', 'HEAD']);
    await File(path.join(source.path, 'project.yml')).writeAsString('name: another\n');
    await _git(source, ['commit', '-am', 'Unverified tip']);
    tip = await _git(source, ['rev-parse', 'HEAD']);
    await File(path.join(scratch.path, 'signing.pub')).writeAsString(_signing);
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

  Future<void> open(WidgetTester tester, {String? commit, String? url, bool chooseFolder = true}) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (chooseFolder) await settings.rememberTresorFolder('demo', folder.path);
    final backend = _Following([
      Followed(name: 'another', url: '/unreadable-other-project', commit: tip),
      Followed(name: 'demo', url: url ?? source.path, commit: commit ?? verified),
    ]);
    machines = Machines(settings, reach: (_) => backend, tunnels: FakeTunnels());
    runs = HostRuns(machines);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(
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
      await tester.enterText(find.byKey(const Key('host-signing-key')), path.join(scratch.path, 'signing.pub'));
    }
    await tester.pump();
  }

  Future<void> put(WidgetTester tester) async {
    final next = tester.widget<FilledButton>(find.byKey(const Key('wizard-next'))).onPressed!;
    await tester.runAsync(() async {
      await Function.apply(next, const []);
    });
    await World.settle(tester);
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
      'wireguard.key',
    }, reason: 'no staging directory may remain after publication');
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
      // The action checks every step again even if navigation has been bypassed.
      final wizard = tester.widget<Wizard>(find.byType(Wizard));
      // Reach the key fields when the drive itself has already accepted the source.
      if (tester.widget<FilledButton>(find.byKey(const Key('wizard-next'))).onPressed != null) {
        await put(tester);
      } else {
        await tester.runAsync(wizard.actionSteps.single.run);
      }
      expect(starts, isEmpty, reason: 'unreadable or invalid followed sources must never rent a host');
      expect(
        scratchWork().difference(before),
        isEmpty,
        reason: 'failed preparation must remove its private scratch directory',
      );
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
