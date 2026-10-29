import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

import 'host_run_test.dart' show CountingProvider, ScriptedRemote;

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
    expect(placing.command, contains('${(remote as _HomeRemote).home.path}/${HostAct.ownAccount.setupPlace}'));
    expect(placing.command, isNot(contains('-o root')));
  });

  // Harm: following a project uses a missing or unchecked private access repository.
  test('the own-account upload carries and checks the machine and both bundles', () async {
    await upload();
    final copies = remote.commands.where((each) => each.startsWith('copy ')).toList();
    for (final name in ['machine.yml', 'demo.bundle', 'demo-access.bundle']) {
      expect(copies, contains(endsWith('/$name')));
    }
    final checked = remote.runs.lastWhere((each) => each.command.contains('sha256sum'));
    expect(checked.command, contains('${(remote as _HomeRemote).home.path}/${HostAct.ownAccount.setupPlace}'));
    expect(
      checked.input,
      '${sha256.convert(machine.readAsBytesSync())}  machine.yml\n'
      '${sha256.convert(bundle.readAsBytesSync())}  demo.bundle\n'
      '${sha256.convert(accessBundle.readAsBytesSync())}  demo-access.bundle\n',
    );
  });

  // Harm: setup material is readable by another host account despite the upload reporting success.
  test('the installed directory and all three files have private modes and exact contents', () async {
    final home = await Directory('${scratch.path}/person home').create();
    final local = _HomeRemote(home);
    run = HostRun(provider: CountingProvider(), remote: local, emit: (_) {});
    expect(await upload(), isNull);
    final place = Directory('${home.path}/${HostRun.setupPlace(HostAct.ownAccount)}');
    expect((await place.stat()).mode & 0x1ff, 0x1c0, reason: 'the setup directory is 0700');
    final expected = {
      'machine.yml': machine.readAsBytesSync(),
      'demo.bundle': bundle.readAsBytesSync(),
      'demo-access.bundle': accessBundle.readAsBytesSync(),
    };
    expect((await place.list().toList()).map((file) => file.uri.pathSegments.last).toSet(), expected.keys.toSet());
    for (final entry in expected.entries) {
      final file = File('${place.path}/${entry.key}');
      expect(await file.readAsBytes(), entry.value, reason: entry.key);
      expect((await file.stat()).mode & 0x1ff, 0x180, reason: '${entry.key} is 0600');
    }
    expect(await Directory('${place.path}.upload').exists(), isFalse);
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
      final place = '${home.path}/${HostRun.setupPlace(HostAct.ownAccount)}';
      expect(await Directory(place).exists(), isFalse);
      expect(await Directory('$place.upload').exists(), isFalse);
      expect(steps.last.words, contains('demo-access.bundle: FAILED'));
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
    final staging = await Directory('${home.path}/${HostAct.ownAccount.setupPlace}.upload').create(recursive: true);
    final previous = await File('${staging.path}/previous').writeAsString('previous upload');
    run = HostRun(provider: CountingProvider(), remote: _HomeRemote(home), emit: (_) {});
    expect(await upload(), Exit.refused);
    expect(await previous.readAsString(), 'previous upload');
  });

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
      await File('${home.path}/${HostAct.ownAccount.setupPlace}/demo.bundle').readAsBytes(),
      bundle.readAsBytesSync(),
    );
  });

  // Harm: a link substituted between SSH calls redirects installation or cleanup.
  for (final swapped in ['ancestor', 'staging']) {
    test('a substituted $swapped link is refused before installation', () async {
      final home = await Directory('${scratch.path}/person home').create();
      final outside = await Directory('${scratch.path}/outside').create();
      if (swapped == 'ancestor') await Directory('${outside.path}/share/porelo-host').create(recursive: true);
      final previous = await File('${outside.path}/previous').writeAsString('keep');
      final target = swapped == 'ancestor'
          ? '${home.path}/.local'
          : '${home.path}/${HostAct.ownAccount.setupPlace}.upload';
      final local = _HomeRemote(
        home,
        afterStaging: () async {
          await Directory(target).rename('$target-kept');
          if (swapped == 'staging') {
            await machine.copy('${outside.path}/machine.yml');
            await bundle.copy('${outside.path}/demo.bundle');
            await accessBundle.copy('${outside.path}/demo-access.bundle');
          }
          await Link(target).create(outside.path);
        },
      );
      run = HostRun(provider: CountingProvider(), remote: local, emit: (_) {});

      expect(await upload(), Exit.refused);
      expect(await previous.readAsString(), 'keep');
      expect(await Link(target).target(), outside.path);
      expect(await Directory('${outside.path}/share/porelo-host/setup').exists(), isFalse);
      expect(await Directory('${home.path}/${HostAct.ownAccount.setupPlace}').exists(), isFalse);
    });
  }

  // Harm: recursive cleanup deletes an unrelated file added during placement.
  test('placement failure preserves an unrelated file in the reserved setup', () async {
    final home = await Directory('${scratch.path}/person home').create();
    final place = '${home.path}/${HostAct.ownAccount.setupPlace}';
    final local = _HomeRemote(
      home,
      installHook:
          'printf keep > ${quoteForAShell('$place/unrelated')}; '
          '/usr/bin/rm -- ${quoteForAShell('$place.upload/demo.bundle')}',
    );
    run = HostRun(provider: CountingProvider(), remote: local, emit: (_) {});

    expect(await upload(), Exit.refused);
    expect(await File('$place/unrelated').readAsString(), 'keep');
    expect(await File('$place/machine.yml').exists(), isFalse);
    expect(await Directory('$place.upload').exists(), isFalse);
  });

  // Harm: a competing upload's setup is overwritten or removed after staging succeeds.
  test('a setup created while staging is checked is refused and preserved', () async {
    final home = await Directory('${scratch.path}/person home').create();
    final place = '${home.path}/${HostAct.ownAccount.setupPlace}';
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
    expect(await Directory('$place.upload').exists(), isFalse);
  });

  // Harm: failed placement leaves a partial setup for the host to consume.
  test('a placement failure removes only the setup and staging this upload created', () async {
    final home = await Directory('${scratch.path}/person home').create();
    final parent = await Directory('${home.path}/.local/share/porelo-host').create(recursive: true);
    final previous = await File('${parent.path}/previous').writeAsString('keep');
    final local = _HomeRemote(home, beforeInstall: () => File('${parent.path}/setup.upload/demo.bundle').delete());
    run = HostRun(provider: CountingProvider(), remote: local, emit: (_) {});

    expect(await upload(), Exit.refused);
    expect(await previous.readAsString(), 'keep');
    expect(await Directory('${parent.path}/setup').exists(), isFalse);
    expect(await Directory('${parent.path}/setup.upload').exists(), isFalse);
  });

  // Harm: private project files escape the person's home through a linked parent.
  for (
    var parent = path.posix.dirname(HostAct.ownAccount.setupPlace);
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
      final place = '${home.path}/${HostAct.ownAccount.setupPlace}';
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
  }) : super([]);

  final Directory home;
  final bool? corruptStaging;
  final Future<void> Function()? afterStaging;
  final Future<void> Function()? beforeInstall;
  final String? homeValue;
  final Directory? copyDirectory;
  final String? installHook;

  @override
  Future<RemoteResult> run(
    String host,
    String user,
    String command, {
    String? input,
    void Function(String line)? onLine,
  }) async {
    await super.run(host, user, command, input: input);
    if (command.contains('sudo')) return const RemoteResult(65, 'sudo is forbidden in the own account');
    if (command.contains('sha256sum') &&
        corruptStaging != null &&
        !command.contains('install -m 0600') == corruptStaging) {
      final folder = '${home.path}/${HostAct.ownAccount.setupPlace}${corruptStaging! ? '.upload' : ''}';
      command = command.replaceFirst(
        '/usr/bin/sha256sum -c -',
        'printf changed > ${quoteForAShell('$folder/demo-access.bundle')}; /usr/bin/sha256sum -c -',
      );
    }
    if (command.contains('install -m 0600')) await beforeInstall?.call();
    if (installHook != null) {
      command = command.replaceFirst('/usr/bin/install -m 0600', '{ $installHook; } && /usr/bin/install -m 0600');
    }
    final process = await Process.start(
      '/bin/bash',
      ['--noprofile', '--norc', '-c', 'umask 000;\n$command'],
      workingDirectory: home.path,
      environment: {'HOME': homeValue ?? home.path, 'BASH_ENV': '/dev/null', 'ENV': '/dev/null'},
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
    if (code == 0 && command.contains('sha256sum') && !command.contains('install -m 0600')) await afterStaging?.call();
    return RemoteResult(code, await error);
  }

  @override
  Future<RemoteResult> copy(String host, String user, String from, String to) async {
    await super.copy(host, user, from, to);
    await File(from).copy(to.startsWith('/') ? to : '${(copyDirectory ?? home).path}/$to');
    return const RemoteResult(0, '');
  }
}
