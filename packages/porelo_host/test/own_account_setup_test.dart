// Linux: the own-account setup script runs in /bin/bash against a home on this computer.
@Tags(<String>['linux'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

import 'host_run_test.dart' show CountingProvider, ScriptedRemote;

String _stagingPlace(String place) =>
    path.posix.join(path.posix.dirname(place), '-upload-${path.posix.basename(place)}');

void main() {
  late Directory scratch;
  late File machine;
  late File bundle;
  late File accessBundle;
  late ScriptedRemote remote;
  late HostRun run;

  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('porelo-own-setup-');
    machine = await File('${scratch.path}/machine.yml').writeAsString('project:\n  name: "demo"\n');
    bundle = await File('${scratch.path}/project.bundle').writeAsBytes([0, 1, 2, 255]);
    accessBundle = await File('${scratch.path}/access.bundle').writeAsBytes([3, 4, 5, 254]);
    remote = _HomeRemote(await Directory('${scratch.path}/person home').create());
    run = HostRun(
      provider: CountingProvider(),
      remote: remote,
      emit: (_) {},
      environment: {'XDG_STATE_HOME': scratch.path, 'LOCALAPPDATA': scratch.path},
      hostKeys: () async => ('fixture', 'ssh-ed25519 AAAA'),
    );
  });
  tearDown(() async => scratch.delete(recursive: true));

  Future<int?> upload() => run.uploadSetupFiles(
    act: HostAct.ownAccount,
    address: '203.0.113.7',
    user: 'developer',
    project: 'demo',
    machineFile: machine.path,
    bundle: bundle.path,
    accessBundle: accessBundle.path,
  );

  // Harm: project files require root or are installed into another account's setup.
  test('the own-account upload stays in the person home without sudo', () async {
    expect(await upload(), isNull);
    expect(remote.commands, everyElement(isNot(contains('sudo'))));
    expect(remote.users, everyElement('developer'));
    final placing = remote.runs.singleWhere((each) => each.command.contains('install -m 0600'));
    expect(
      placing.command,
      contains('${(remote as _HomeRemote).home.path}/${HostAct.ownAccount.setupPlace(project: 'demo')}'),
    );
    expect(placing.command, isNot(contains('-o root')));
  });

  // Harm: following a project uses a missing or unchecked private access repository.
  test('the own-account upload carries and checks the machine and both bundles', () async {
    await upload();
    final copies = remote.commands.where((each) => each.startsWith('copy ')).toList();
    for (final name in ['machine.yml', 'project.bundle', 'access.bundle']) {
      expect(copies, contains(endsWith('/$name')));
    }
    final checked = remote.runs.lastWhere((each) => each.command.contains('sha256sum'));
    expect(
      checked.command,
      contains('${(remote as _HomeRemote).home.path}/${HostAct.ownAccount.setupPlace(project: 'demo')}'),
    );
    expect(
      checked.input,
      '${sha256.convert(machine.readAsBytesSync())}  machine.yml\n'
      '${sha256.convert(bundle.readAsBytesSync())}  project.bundle\n'
      '${sha256.convert(accessBundle.readAsBytesSync())}  access.bundle\n',
    );
  });

  // Harm: setup material is readable by another host account despite the upload reporting success.
  test('the installed directory and all three files have private modes and exact contents', () async {
    final home = await Directory('${scratch.path}/person home').create();
    final local = _HomeRemote(home);
    run = HostRun(provider: CountingProvider(), remote: local, emit: (_) {});
    expect(await upload(), isNull);
    final place = Directory('${home.path}/${HostRun.setupPlace(HostAct.ownAccount, project: 'demo')}');
    expect((await place.stat()).mode & 0x1ff, 0x1c0, reason: 'the setup directory is 0700');
    final expected = {
      'machine.yml': machine.readAsBytesSync(),
      'project.bundle': bundle.readAsBytesSync(),
      'access.bundle': accessBundle.readAsBytesSync(),
    };
    expect((await place.list().toList()).map((file) => file.uri.pathSegments.last).toSet(), expected.keys.toSet());
    for (final entry in expected.entries) {
      final file = File('${place.path}/${entry.key}');
      expect(await file.readAsBytes(), entry.value, reason: entry.key);
      expect((await file.stat()).mode & 0x1ff, 0x180, reason: '${entry.key} is 0600');
    }
    expect(await Directory(_stagingPlace(place.path)).exists(), isFalse);
    expect(local.commands, everyElement(isNot(contains('sudo'))));
    expect(local.users, everyElement('developer'));
  });

  // Harm: corrupted project or access data is consumed as if it arrived intact.
  for (final stage in [true, false]) {
    test('a changed access bundle ${stage ? 'on arrival' : 'in place'} is refused and removed', () async {
      final home = await Directory('${scratch.path}/person home').create();
      final local = _HomeRemote(home, corruptStaging: stage);
      final steps = <Step>[];
      run = HostRun(provider: CountingProvider(), remote: local, emit: steps.add);
      expect(await upload(), Exit.refused);
      final place = '${home.path}/${HostRun.setupPlace(HostAct.ownAccount, project: 'demo')}';
      expect(await Directory(place).exists(), isFalse);
      expect(await Directory(_stagingPlace(place)).exists(), isFalse);
      expect(steps.last.words, contains('access.bundle: FAILED'));
      expect(
        local.commands.where((command) => command.contains('install -m 0600')),
        stage ? isEmpty : isNotEmpty,
        reason: 'only files that arrived intact may be installed',
      );
    });
  }

  // Harm: an interrupted upload's files are deleted by a later run that does not own them.
  test('an existing staging directory is refused with its files intact', () async {
    final home = await Directory('${scratch.path}/person home').create();
    final staging = await Directory(_stagingPlace('${home.path}/${HostAct.ownAccount.setupPlace(project: 'demo')}'))
        .create(recursive: true);
    final previous = await File('${staging.path}/previous').writeAsString('previous upload');
    run = HostRun(provider: CountingProvider(), remote: _HomeRemote(home), emit: (_) {});
    expect(await upload(), Exit.refused);
    expect(await previous.readAsString(), 'previous upload');
  });

  for (final session in [1, 2, 3, 4]) {
    test('startup output in session $session refuses the upload and preserves unproven files', () async {
      final home = await Directory('${scratch.path}/person home').create();
      final local = _HomeRemote(home, noisySession: session);
      run = HostRun(provider: CountingProvider(), remote: local, emit: (_) {});
      expect(await upload(), Exit.refused);
      final place = '${home.path}/${HostAct.ownAccount.setupPlace(project: 'demo')}';
      expect(await Directory(place).exists(), session == 4);
      if (session == 4) {
        expect(await File('$place/machine.yml').readAsBytes(), machine.readAsBytesSync());
      }
      expect(await Directory(_stagingPlace(place)).exists(), isFalse);
      if (session <= 2) expect(local.commands.where((command) => command.startsWith('copy ')), isEmpty);
    });
  }

  // Harm: a shell wrapper exits successfully without running the reservation or placement, and cleanup deletes another upload.
  for (final session in [2, 4]) {
    test('an early successful login exit in session $session preserves existing setup names', () async {
      final home = (remote as _HomeRemote).home;
      final place = '${home.path}/${HostAct.ownAccount.setupPlace(project: 'demo')}';
      final target = session == 2 ? _stagingPlace(place) : place;
      remote = _HomeRemote(
        home,
        noisySession: session,
        skipSession: session,
        beforeSession: (number) async {
          if (number != session) return;
          await Directory(target).create(recursive: true);
          for (final name in ['machine.yml', 'project.bundle', 'access.bundle']) {
            await File('$target/$name').writeAsString('another upload');
          }
        },
      );
      run = HostRun(provider: CountingProvider(), remote: remote, emit: (_) {});
      expect(await upload(), Exit.refused);
      for (final name in ['machine.yml', 'project.bundle', 'access.bundle']) {
        expect(await File('$target/$name').readAsString(), 'another upload');
      }
      if (session == 4) expect(await Directory(_stagingPlace(target)).exists(), isFalse);
    });
  }

  // Harm: a second project overwrites the first project's setup or makes the host read old bundle names.
  test('each project receives only the three fixed names in its own private directory', () async {
    final home = (remote as _HomeRemote).home;
    expect(await upload(), isNull);
    final secondMachine = await File('${scratch.path}/other-machine.yml').writeAsString('project: {name: other}\n');
    expect(
      await run.uploadSetupFiles(
        act: HostAct.ownAccount,
        address: '203.0.113.7',
        user: 'developer',
        project: 'other',
        machineFile: secondMachine.path,
        bundle: bundle.path,
        accessBundle: accessBundle.path,
      ),
      isNull,
    );
    for (final (project, expectedMachine) in [('demo', machine), ('other', secondMachine)]) {
      final folder = Directory('${home.path}/.local/share/porelo-host/setup/$project');
      expect(folder.existsSync(), isTrue);
      expect(folder.statSync().mode & 0x1ff, 0x1c0);
      expect(folder.listSync().map((entry) => path.basename(entry.path)).toSet(), {
        'machine.yml',
        'project.bundle',
        'access.bundle',
      });
      for (final (name, source) in [
        ('machine.yml', expectedMachine),
        ('project.bundle', bundle),
        ('access.bundle', accessBundle),
      ]) {
        final installed = File('${folder.path}/$name');
        expect(installed.readAsBytesSync(), source.readAsBytesSync());
        expect(installed.statSync().mode & 0x1ff, 0x180);
      }
    }
    expect(
      Directory('${home.path}/.local/share/porelo-host/setup')
          .listSync()
          .map((entry) => path.basename(entry.path))
          .toSet(),
      {'demo', 'other'},
    );
  });

  // Harm: a harmless early shell exit falsely claims cleanup failed and obscures what was actually left behind.
  test('startup output before placement leaves no destination and reports no cleanup failure', () async {
    final home = (remote as _HomeRemote).home;
    final steps = <Step>[];
    remote = _HomeRemote(home, noisySession: 4, skipSession: 4);
    run = HostRun(provider: CountingProvider(), remote: remote, emit: steps.add);
    expect(await upload(), Exit.refused);
    expect(steps.last.words, contains('unexpected startup output'));
    expect(steps.last.words, isNot(contains('Cannot safely clean setup')));
    expect(await Directory('${home.path}/${HostAct.ownAccount.setupPlace(project: 'demo')}').exists(), isFalse);
    expect(
      await Directory(_stagingPlace('${home.path}/${HostAct.ownAccount.setupPlace(project: 'demo')}')).exists(),
      isFalse,
    );
  });

  // Harm: one project's installed setup collides with another project's staging directory.
  test('a project ending in .upload does not block or receive another project staging', () async {
    final home = (remote as _HomeRemote).home;
    expect(
      await run.uploadSetupFiles(
        act: HostAct.ownAccount,
        address: '203.0.113.7',
        user: 'developer',
        project: 'demo.upload',
        machineFile: machine.path,
        bundle: bundle.path,
        accessBundle: accessBundle.path,
      ),
      isNull,
    );
    expect(await upload(), isNull);
    final copies = (remote as _HomeRemote).copiedTo;
    expect(copies, hasLength(6));
    for (final file in copies) {
      final stagingName = path.posix.basename(path.posix.dirname(file));
      expect(
        () => HostFiles.checkName(stagingName),
        throwsA(isA<HostFilesRefused>()),
        reason: 'a staging directory cannot name a project',
      );
    }
    for (final project in ['demo', 'demo.upload']) {
      final place = '${home.path}/${HostAct.ownAccount.setupPlace(project: project)}';
      expect(await File('$place/project.bundle').readAsBytes(), bundle.readAsBytesSync());
      expect(await File('$place/access.bundle').readAsBytes(), accessBundle.readAsBytesSync());
    }
  });

  // Harm: a project name a shell, scp or YAML reads otherwise reaches the remote setup folder.
  for (final project in ['demo\nother', 'demo:x', 'demo.', 'demo+1']) {
    test('the upload refuses the project name ${project.replaceAll('\n', r'\n')} before any remote call', () async {
      await expectLater(
        run.uploadSetupFiles(
          act: HostAct.ownAccount,
          address: '203.0.113.7',
          user: 'developer',
          project: project,
          machineFile: machine.path,
          bundle: bundle.path,
          accessBundle: accessBundle.path,
        ),
        throwsA(isA<HostFilesRefused>()),
      );
      expect((remote as _HomeRemote).commands, isEmpty);
    });
  }

  // Harm: a project accepted by metadata cannot finish its upload because another validator disagrees.
  test('the upload accepts a project name accepted by the shared name check', () async {
    expect(
      await run.uploadSetupFiles(
        act: HostAct.ownAccount,
        address: '203.0.113.7',
        user: 'developer',
        project: 'demo.v1_x-2',
        machineFile: machine.path,
        bundle: bundle.path,
        accessBundle: accessBundle.path,
      ),
      isNull,
    );
  });

  // Harm: a noncanonical account home redirects private setup data after the path is silently normalized.
  for (final suffix in ['/', '//', '/.', '/..', '/./x', '/../x']) {
    test('an unnormalized HOME ending $suffix is refused before copying', () async {
      final home = (remote as _HomeRemote).home;
      // A dot segment names a folder that exists, so only the dot-segment check can refuse it.
      final named = suffix.endsWith('/x') ? await Directory(path.normalize('${home.path}$suffix')).create() : null;
      remote = _HomeRemote(home, homeValue: '${home.path}$suffix');
      run = HostRun(provider: CountingProvider(), remote: remote, emit: (_) {});
      expect(await upload(), Exit.refused);
      expect(remote.commands.where((command) => command.startsWith('copy ')), isEmpty);
      expect(await home.list().where((entry) => entry.path != named?.path).toList(), isEmpty);
      if (named != null) expect(await named.list().toList(), isEmpty);
    });
  }

  // Harm: an invalid home redirects private setup files outside the account's directory.
  for (final kind in ['empty', 'relative', 'link', 'link with trailing slash']) {
    test('an invalid HOME ($kind) is refused before creating or copying setup files', () async {
      final home = await Directory('${scratch.path}/person home').create();
      final linkedHome = Link('${scratch.path}/linked-home');
      await linkedHome.create(home.path);
      final value = switch (kind) {
        'empty' => '',
        'relative' => '.',
        'link' => linkedHome.path,
        _ => '${linkedHome.path}/',
      };
      final local = _HomeRemote(home, homeValue: value);
      run = HostRun(provider: CountingProvider(), remote: local, emit: (_) {});

      expect(await upload(), Exit.refused);
      expect(local.commands.where((command) => command.startsWith('copy ')), isEmpty);
      expect(await home.list().toList(), isEmpty);
    });
  }

  // Harm: scp's initial directory differs from HOME and receives private bundles there.
  test('copies target the checked absolute home even when the login starts elsewhere', () async {
    final home = await Directory('${scratch.path}/person home').create();
    final elsewhere = await Directory('${scratch.path}/elsewhere').create();
    final local = _HomeRemote(home, copyDirectory: elsewhere);
    run = HostRun(provider: CountingProvider(), remote: local, emit: (_) {});

    expect(await upload(), isNull);
    expect(await elsewhere.list().toList(), isEmpty);
    expect(
      await File('${home.path}/${HostAct.ownAccount.setupPlace(project: 'demo')}/project.bundle').readAsBytes(),
      bundle.readAsBytesSync(),
    );
  });

  // Harm: a link substituted between SSH calls redirects installation or cleanup.
  for (final swapped in ['ancestor', 'staging']) {
    test('a substituted $swapped link is refused before installation', () async {
      final home = await Directory('${scratch.path}/person home').create();
      final outside = await Directory('${scratch.path}/outside').create();
      final outsideStaging = swapped == 'ancestor'
          ? '${outside.path}/share/porelo-host/setup/-upload-demo'
          : outside.path;
      await Directory(outsideStaging).create(recursive: true);
      final previous = await File('${outside.path}/previous').writeAsString('keep');
      final target = swapped == 'ancestor'
          ? '${home.path}/.local'
          : _stagingPlace('${home.path}/${HostAct.ownAccount.setupPlace(project: 'demo')}');
      final local = _HomeRemote(
        home,
        afterStaging: () async {
          await Directory(target).rename('$target-kept');
          await machine.copy('$outsideStaging/machine.yml');
          await bundle.copy('$outsideStaging/project.bundle');
          await accessBundle.copy('$outsideStaging/access.bundle');
          await Link(target).create(outside.path);
        },
      );
      run = HostRun(provider: CountingProvider(), remote: local, emit: (_) {});

      expect(await upload(), Exit.refused);
      expect(await previous.readAsString(), 'keep');
      expect(await Link(target).target(), outside.path);
      expect(await Directory('${outside.path}/share/porelo-host/setup/demo').exists(), isFalse);
      expect(await File('$outsideStaging/machine.yml').readAsBytes(), machine.readAsBytesSync());
      expect(await File('$outsideStaging/project.bundle').readAsBytes(), bundle.readAsBytesSync());
      expect(await File('$outsideStaging/access.bundle').readAsBytes(), accessBundle.readAsBytesSync());
      expect(await Directory('${home.path}/${HostAct.ownAccount.setupPlace(project: 'demo')}').exists(), isFalse);
    });
  }

  // Harm: recursive cleanup deletes an unrelated file added during placement.
  test('placement failure preserves an unrelated file in the reserved setup', () async {
    final home = await Directory('${scratch.path}/person home').create();
    final place = '${home.path}/${HostAct.ownAccount.setupPlace(project: 'demo')}';
    final local = _HomeRemote(
      home,
      installHook:
          'printf keep > ${quoteForAShell('$place/unrelated')}; '
          '/usr/bin/rm -- ${quoteForAShell('${_stagingPlace(place)}/project.bundle')}',
    );
    run = HostRun(provider: CountingProvider(), remote: local, emit: (_) {});

    expect(await upload(), Exit.refused);
    expect(await File('$place/unrelated').readAsString(), 'keep');
    expect(await File('$place/machine.yml').exists(), isFalse);
    expect(await Directory(_stagingPlace(place)).exists(), isFalse);
  });

  // Harm: a competing upload's setup is overwritten or removed after staging succeeds.
  test('a setup created while staging is checked is refused and preserved', () async {
    final home = await Directory('${scratch.path}/person home').create();
    final place = '${home.path}/${HostAct.ownAccount.setupPlace(project: 'demo')}';
    final local = _HomeRemote(
      home,
      afterStaging: () async {
        await Directory(place).create();
        await File('$place/previous').writeAsString('keep');
      },
    );
    run = HostRun(provider: CountingProvider(), remote: local, emit: (_) {});

    expect(await upload(), Exit.refused);
    expect(await File('$place/previous').readAsString(), 'keep');
    expect((await Directory(place).list().toList()).map((entry) => entry.path), ['$place/previous']);
    expect(await Directory(_stagingPlace(place)).exists(), isFalse);
  });

  // Harm: failed placement leaves a partial setup for the host to consume.
  test('a placement failure removes only the setup and staging this upload created', () async {
    final home = await Directory('${scratch.path}/person home').create();
    final parent = await Directory('${home.path}/.local/share/porelo-host').create(recursive: true);
    final previous = await File('${parent.path}/previous').writeAsString('keep');
    final local = _HomeRemote(
      home,
      beforeInstall: () => File('${parent.path}/setup/-upload-demo/project.bundle').delete(),
    );
    run = HostRun(provider: CountingProvider(), remote: local, emit: (_) {});

    expect(await upload(), Exit.refused);
    expect(await previous.readAsString(), 'keep');
    expect(await Directory('${parent.path}/setup/demo').exists(), isFalse);
    expect(await Directory('${parent.path}/setup/-upload-demo').exists(), isFalse);
  });

  // Harm: private project files escape the person's home through a linked parent.
  for (
    var parent = path.posix.dirname(HostAct.ownAccount.setupPlace(project: 'demo'));
    parent != '.';
    parent = path.posix.dirname(parent)
  ) {
    final checkedParent = parent;
    test('a linked $checkedParent is refused before copying any files', () async {
      final home = await Directory('${scratch.path}/person home').create();
      final outside = await Directory('${scratch.path}/outside').create();
      final link = Link('${home.path}/$checkedParent');
      await link.parent.create(recursive: true);
      await link.create(outside.path);
      final previous = await File('${outside.path}/previous').writeAsString('keep');
      final local = _HomeRemote(home);
      run = HostRun(provider: CountingProvider(), remote: local, emit: (_) {});

      expect(await upload(), Exit.refused);
      expect(local.commands.where((command) => command.startsWith('copy ')), isEmpty);
      expect(await link.target(), outside.path);
      expect(await previous.readAsString(), 'keep');
      expect((await outside.list().toList()).map((entry) => entry.path), [previous.path]);
    });
  }

  // Harm: an upload overwrites or deletes setup material owned by an earlier run.
  for (final kind in ['directory', 'link', 'dangling link', 'file']) {
    test('an existing setup $kind is refused and preserved', () async {
      final home = await Directory('${scratch.path}/person home').create();
      final place = '${home.path}/${HostAct.ownAccount.setupPlace(project: 'demo')}';
      await Directory(place).parent.create(recursive: true);
      final outside = await Directory('${scratch.path}/outside').create();
      final previous = await File('${outside.path}/previous').writeAsString('keep');
      switch (kind) {
        case 'directory':
          await Directory(place).create();
          await File('$place/previous').writeAsString('keep');
        case 'link':
          await Link(place).create(outside.path);
        case 'dangling link':
          await Link(place).create('${scratch.path}/missing');
        case 'file':
          await File(place).writeAsString('keep');
      }
      final local = _HomeRemote(home);
      run = HostRun(provider: CountingProvider(), remote: local, emit: (_) {});

      expect(await upload(), Exit.refused);
      expect(local.commands.where((command) => command.startsWith('copy ')), isEmpty);
      expect(await previous.readAsString(), 'keep');
      switch (kind) {
        case 'directory':
          expect(await File('$place/previous').readAsString(), 'keep');
          expect((await Directory(place).list().toList()).map((entry) => entry.path), ['$place/previous']);
        case 'link':
          expect(await Link(place).target(), outside.path);
        case 'dangling link':
          expect(await Link(place).target(), '${scratch.path}/missing');
        case 'file':
          expect(await File(place).readAsString(), 'keep');
      }
    });
  }

  // Harm: project material is installed into a server-only or legacy root setup.
  for (final (act, access) in [(HostAct.root, false), (HostAct.root, true), (HostAct.legacyUp, true)]) {
    test('${act.name} refuses project upload with access bundle $access before remote work', () async {
      await expectLater(
        run.uploadSetupFiles(
          act: act,
          address: '203.0.113.7',
          user: 'developer',
          project: 'demo',
          machineFile: machine.path,
          bundle: bundle.path,
          accessBundle: access ? accessBundle.path : null,
        ),
        throwsFormatException,
      );
      expect(remote.commands, isEmpty);
    });
  }

  // Harm: an incomplete or privileged bring starts copying before its inputs are refused.
  test('missing access data and root logins are refused before any upload', () async {
    for (final (user, access) in [
      ('developer', null),
      ('developer', '${scratch.path}/missing'),
      ('root', accessBundle.path),
    ]) {
      await expectLater(
        run.uploadSetupFiles(
          act: HostAct.ownAccount,
          address: '203.0.113.7',
          user: user,
          project: 'demo',
          machineFile: machine.path,
          bundle: bundle.path,
          accessBundle: access,
        ),
        throwsFormatException,
      );
    }
    expect(remote.commands, isEmpty);
  });
}

/// Executes the upload's commands in a private home; sudo is refused before it can run.
class _HomeRemote extends ScriptedRemote {
  _HomeRemote(
    this.home, {
    this.corruptStaging,
    this.afterStaging,
    this.beforeInstall,
    this.homeValue,
    this.copyDirectory,
    this.installHook,
    this.noisySession,
    this.skipSession,
    this.beforeSession,
  }) : super([]);

  final Directory home;
  final copiedTo = <String>[];
  final bool? corruptStaging;
  final Future<void> Function()? afterStaging;
  final Future<void> Function()? beforeInstall;
  final String? homeValue;
  final Directory? copyDirectory;
  final String? installHook;
  final int? noisySession;
  final int? skipSession;
  final Future<void> Function(int)? beforeSession;

  @override
  Future<RemoteResult> run(
    String host,
    String user,
    String command, {
    String? input,
    void Function(String line)? onLine,
  }) async {
    await super.run(host, user, command, input: input);
    var script = command;
    if (script.contains('sudo')) return const RemoteResult(65, 'sudo is forbidden in the own account');
    if (script.contains('sha256sum') &&
        corruptStaging != null &&
        !script.contains('install -m 0600') == corruptStaging) {
      final place = '${home.path}/${HostAct.ownAccount.setupPlace(project: 'demo')}';
      final folder = corruptStaging! ? _stagingPlace(place) : place;
      script = script.replaceFirst(
        '/usr/bin/sha256sum --quiet -c -',
        '{ printf changed > ${quoteForAShell('$folder/access.bundle')}; /usr/bin/sha256sum --quiet -c -; }',
      );
    }
    if (script.contains('install -m 0600')) await beforeInstall?.call();
    if (installHook != null) {
      script = script.replaceFirst('/usr/bin/install -m 0600', '{ $installHook; } && /usr/bin/install -m 0600');
    }
    command = script;
    await beforeSession?.call(runs.length);
    final process = await Process.start(
      '/bin/bash',
      [
        '-c',
        'umask 000;\n${runs.length == noisySession ? "printf 'shell startup output\\n';\n" : ""}${runs.length == skipSession ? "/usr/bin/cat >/dev/null; exit 0" : command}',
      ],
      workingDirectory: home.path,
      environment: {'HOME': homeValue ?? home.path, 'PATH': '/usr/bin:/bin', 'LC_ALL': 'C'},
      includeParentEnvironment: false,
    );
    final output = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) => onLine?.call(line));
    final error = process.stderr.transform(utf8.decoder).join();
    SocketException? inputFailure;
    try {
      if (input != null) process.stdin.write(input);
      await process.stdin.close();
    } on SocketException catch (error) {
      // A path refusal can end Bash before it reads the checksum input.
      inputFailure = error;
    }
    final code = await process.exitCode;
    await output;
    if (code == 0 && inputFailure != null) throw inputFailure;
    if (code == 0 && script.contains('sha256sum') && !script.contains('install -m 0600')) await afterStaging?.call();
    return RemoteResult(code, await error);
  }

  @override
  Future<RemoteResult> copy(String host, String user, String from, String to) async {
    await super.copy(host, user, from, to);
    await File(from).copy(to.startsWith('/') ? to : '${(copyDirectory ?? home).path}/$to');
    copiedTo.add(to);
    return const RemoteResult(0, '');
  }
}
