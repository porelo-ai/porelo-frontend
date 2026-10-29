import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
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
    remote = ScriptedRemote([]);
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
    await upload();
    expect(remote.commands, everyElement(isNot(contains('sudo'))));
    expect(remote.users, everyElement('developer'));
    final placing = remote.runs.singleWhere((each) => each.command.contains('install -m 0600'));
    expect(placing.command, contains(r'"$HOME"/.local/share/porelo-host/setup'));
    expect(placing.command, contains('install -d -m 0700'));
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
    expect(checked.command, contains(r'"$HOME"/.local/share/porelo-host/setup'));
    expect(
      checked.input,
      '${sha256.convert(machine.readAsBytesSync())}  machine.yml\n'
      '${sha256.convert(bundle.readAsBytesSync())}  demo.bundle\n'
      '${sha256.convert(accessBundle.readAsBytesSync())}  demo-access.bundle\n',
    );
  });

  // Harm: setup material is readable by another host account despite the upload reporting success.
  test('the installed directory and all three files are private and owned by the login', () async {
    final home = await Directory('${scratch.path}/person home').create();
    final local = _HomeRemote(home);
    run = HostRun(provider: CountingProvider(), remote: local, emit: (_) {});
    expect(await upload(), isNull);
    final place = Directory('${home.path}/${HostRun.setupPlace(HostAct.ownAccount)}');
    expect((await place.stat()).mode & 0x1ff, 0x1c0, reason: 'the setup directory is 0700');
    final uid = await Process.run('/usr/bin/id', ['-u']);
    expect(uid.exitCode, 0);
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
    for (final file in [place.path, for (final name in expected.keys) '${place.path}/$name']) {
      final owner = await Process.run('/usr/bin/stat', ['-c', '%u', '--', file]);
      expect(owner.exitCode, 0);
      expect(owner.stdout, uid.stdout, reason: 'owned by the login that ran install');
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
  _HomeRemote(this.home, {this.corruptStaging}) : super([]);

  final Directory home;
  final bool? corruptStaging;

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
    if (command.contains('sha256sum') && corruptStaging != null && command.contains('setup.upload') == corruptStaging) {
      final folder = '${home.path}/${HostAct.ownAccount.setupPlace}${corruptStaging! ? '.upload' : ''}';
      await File('$folder/demo-access.bundle').writeAsString('changed after upload');
    }
    final process = await Process.start(
      '/bin/bash',
      ['--noprofile', '--norc', '-c', command],
      workingDirectory: home.path,
      environment: {'HOME': home.path, 'BASH_ENV': '/dev/null', 'ENV': '/dev/null'},
    );
    final output = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) => onLine?.call(line));
    final error = process.stderr.transform(utf8.decoder).join();
    if (input != null) process.stdin.write(input);
    await process.stdin.close();
    final code = await process.exitCode;
    await output;
    return RemoteResult(code, await error);
  }

  @override
  Future<RemoteResult> copy(String host, String user, String from, String to) async {
    await super.copy(host, user, from, to);
    await File(from).copy('${home.path}/$to');
    return const RemoteResult(0, '');
  }
}
