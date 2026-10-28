import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machine_setup.dart';
import 'package:porelo_frontend/src/app/setup_run.dart';

import '../support/tresorit_fixture.dart';

/// A machine whose root answers when told to, so what a run says *while* it waits can be read.
class _Slow extends MachineSetup {
  _Slow(String home) : super(home: home);

  final Completer<ProcessResult> answer = Completer<ProcessResult>();

  @override
  Future<ProcessResult> asRootLive(String host, String keyFile, String script, void Function(String) onLine) {
    onLine('Reading package lists...');
    return answer.future;
  }
}

/// A machine that records every command and what was sent to it, and answers as told.
class _Recording extends MachineSetup {
  _Recording(String home, {this.checkPasses = true}) : super(home: home);

  final bool checkPasses;
  final asUserCommands = <String>[];
  final sent = <String, List<int>>{};
  final rootScripts = <String>[];

  /// Every call in order, with the `Host` entry it went through.
  final log = <String>[];
  final aliases = <String>{};

  @override
  Future<ProcessResult> asUser(String alias, String command) async {
    asUserCommands.add(command);
    aliases.add(alias);
    log.add('run $command');
    if (command.contains('mktemp -d')) return ProcessResult(0, 0, '/home/agent/.cache/porelo-tresorit.Ab12Cd\n', '');
    if (command.contains('/bin/bash -c') && !checkPasses) {
      return ProcessResult(0, 1, '', 'signing.pem: verification failed');
    }
    if (command.contains('-p status')) return ProcessResult(0, 0, 'Logged in as:\tme@example.org\n', '');
    return ProcessResult(0, 0, '', '');
  }

  @override
  Future<ProcessResult> sendToUser(String alias, String path, List<int> bytes) async {
    sent[path] = bytes;
    aliases.add(alias);
    log.add('send $path');
    return ProcessResult(0, 0, '', '');
  }

  @override
  Future<ProcessResult> asRoot(String host, String keyFile, String script) async {
    rootScripts.add(script);
    return ProcessResult(0, 0, '', '');
  }

  @override
  Future<ProcessResult> asRootLive(String host, String keyFile, String script, void Function(String) onLine) async {
    rootScripts.add(script);
    return ProcessResult(0, 0, '', '');
  }
}

void main() {
  late Directory home;

  setUp(() => home = Directory.systemTemp.createTempSync('setup-run-'));
  tearDown(() => home.deleteSync(recursive: true));

  group('the drive', () {
    late TresoritFixture fixture;
    late Uint8List installer;
    late String pin;
    setUp(() async {
      fixture = TresoritFixture(home);
      final made = await fixture.certificates('tresorit');
      installer = await fixture.installer('tresorit', [made.signing, made.ca]);
      pin = fixture.fingerprint(made.ca);
    });

    SetupRun runOn(_Recording machine, {String? pinned}) => SetupRun(
      name: 'x',
      workUser: 'agent',
      setup: machine,
      download: (_) async => installer,
      installerPin: pinned ?? pin,
    )..step = SetupStep.drive;

    // Harm: a user who wants no drive asked about one, or something of Tresorit installed anyway.
    test('a user without a drive is asked nothing about it and runs no step for it', () async {
      final machine = _Recording(home.path);
      final run = runOn(machine);
      expect(run.canGoOn, isTrue, reason: 'the step is left with Next as it is');
      run.next();
      expect(run.step, SetupStep.harden);
      expect(machine.asUserCommands, isEmpty);
      expect(machine.sent, isEmpty);
      expect(machine.rootScripts, isEmpty);
    }, skip: TresoritFixture.skip);

    // Harm: Tresorit's client installed as root or Porelo's account, or an installer run before it was checked.
    test('a chosen drive is installed as that user alone, from an installer checked there first', () async {
      final machine = _Recording(home.path);
      final run = runOn(machine);
      await run.installDrive();
      expect(run.saidIsBad, isFalse, reason: run.said);
      expect(run.driveInstalled, isTrue);
      expect(machine.rootScripts, isEmpty, reason: 'nothing of it as root');
      expect(machine.aliases, {run.alias}, reason: 'everything through the work user\'s own entry');
      int at(String prefix) => machine.log.indexWhere((each) => each.startsWith(prefix));
      final checking = machine.log.indexWhere((each) => each.contains('/bin/bash -c'));
      for (final name in ['installer.run', 'signature.bin', 'signing.pem', 'ca.pem']) {
        expect(machine.log.indexWhere((each) => each.endsWith('/$name')), lessThan(checking), reason: '$name before');
      }
      expect(at('send .config/systemd/user/tresorit-daemon.service'), greaterThan(checking));
      expect(machine.log.indexWhere((each) => each.contains('enable --now')), greaterThan(at('send .config/systemd')));
      final kept = SetupRun.fromStored(run.toStored(), setup: machine)!;
      expect(kept.driveInstalled, isTrue, reason: 'a resumed run does not install it again');
      const folder = '/home/agent/.cache/porelo-tresorit.Ab12Cd';
      expect(
        machine.sent.keys,
        containsAll(['$folder/installer.run', '$folder/signature.bin', '$folder/signing.pem', '$folder/ca.pem']),
      );
      expect(machine.sent['$folder/installer.run'], installer, reason: 'the installer as fetched, which is what runs');
      final check = machine.asUserCommands.indexWhere((each) => each.startsWith('/bin/bash -c'));
      expect(check, greaterThan(-1));
      expect(machine.asUserCommands[check], contains('/usr/bin/openssl verify'));
      expect(
        machine.asUserCommands.indexWhere((each) => each.contains('enable --now tresorit-daemon.service')),
        greaterThan(check),
        reason: 'the daemon only after the installer passed and ran',
      );

      await run.checkDriveLogin();
      expect(run.driveSignedInAs, 'me@example.org');
      run.tresor = 'my files';
      await run.syncDrive();
      expect(machine.asUserCommands.last, contains("sync --start 'my files' --path"));
      expect(run.driveSynced, 'my files');
      final resumed = SetupRun.fromStored(run.toStored(), setup: machine)!;
      expect(
        (resumed.driveSignedInAs, resumed.driveSynced, resumed.tresor),
        ('me@example.org', 'my files', 'my files'),
      );
    }, skip: TresoritFixture.skip);

    test('an installer the machine refuses, or one under another CA, never runs and starts nothing', () async {
      final refusing = _Recording(home.path, checkPasses: false);
      final run = runOn(refusing);
      await run.installDrive();
      expect(run.saidIsBad, isTrue);
      expect(run.said, contains('did not pass its check'));
      expect(run.driveInstalled, isFalse);
      expect(refusing.asUserCommands.where((each) => each.contains('tresorit-daemon')), isEmpty);
      expect(
        refusing.asUserCommands.last,
        '/usr/bin/rm -rf -- /home/agent/.cache/porelo-tresorit.Ab12Cd',
        reason: 'the folder goes even where the check never ran',
      );

      final foreign = _Recording(home.path);
      final other = runOn(foreign, pinned: 'ab' * 32);
      await other.installDrive();
      expect(other.said, contains('pinned fingerprint'));
      expect(foreign.sent, isEmpty, reason: 'nothing is sent before the pinned CA is found');
      expect(foreign.asUserCommands, isEmpty);
    }, skip: TresoritFixture.skip);

    test('a tresor name or an e-mail that would reach the shell as more than a word is refused or quoted', () async {
      final machine = _Recording(home.path);
      final run = runOn(machine);
      for (final bad in ["a'b", r'a$(id)', 'a;b', '', '-x']) {
        run.tresor = bad;
        await run.syncDrive();
        expect(run.saidIsBad, isTrue, reason: bad);
      }
      expect(machine.asUserCommands, isEmpty);
      for (final bad in ["me'@example.org", r'me$(id)@example.org', 'me @example.org', '-me', '']) {
        expect(() => run.driveLoginCommand(bad), throwsFormatException, reason: bad);
      }
      expect(
        run.driveLoginCommand('me+drive@example.org').last,
        contains('--email me+drive@example.org --password-on-stdin'),
      );
    }, skip: TresoritFixture.skip);
  });

  test('what a run keeps never holds a private key, only where a kept one lives', () async {
    Map<String, Object?>? kept;
    final run = SetupRun(
      name: 'the build machine',
      workUser: 'agent',
      setup: MachineSetup(home: home.path),
      remember: (draft) async => kept = draft,
    );
    await run.generate();
    expect(kept.toString(), isNot(contains('PRIVATE')));
    expect(kept!['publicKey'], isEmpty, reason: 'a key not kept yet was kept');

    await run.keep();

    expect(kept.toString(), isNot(contains('PRIVATE')));
    expect(kept!['kept'], '${home.path}/.ssh/porelo-the-build-machine-admin');
    expect(kept!['publicKey'], startsWith('ssh-ed25519 '));
  });

  test('a run picked up again starts where it can go on, and root logs in again first', () {
    final key = File('${home.path}/porelo-x')..writeAsStringSync('key');
    final run = SetupRun.fromStored(<String, Object?>{
      'name': 'x',
      'workUser': 'agent',
      'step': 'reach',
      'kept': key.path,
      'host': '203.0.113.10',
      'prepared': false,
    }, setup: MachineSetup(home: home.path))!;

    expect(run.step, SetupStep.where, reason: 'a run not prepared went past root logging in');
    expect(run.host, '203.0.113.10');
    expect(run.loggedInTo, isNull);
  });

  test('a kept key that is gone sends the run back to the key', () {
    final run = SetupRun.fromStored(<String, Object?>{
      'name': 'x',
      'workUser': 'agent',
      'step': 'prepare',
      'kept': '${home.path}/gone',
    }, setup: MachineSetup(home: home.path))!;

    expect(run.step, SetupStep.key);
    expect(run.kept, isNull);
  });

  test('something that is not a run is not picked up', () {
    expect(SetupRun.fromStored(<String, Object?>{'name': ''}, setup: MachineSetup(home: home.path)), isNull);
  });

  test('while a script runs, the run says what it is doing and shows what it printed', () async {
    final slow = _Slow(home.path);
    final run = SetupRun(name: 'x', workUser: 'agent', setup: slow)
      ..kept = '/k'
      ..loggedInTo = '203.0.113.10'
      ..step = SetupStep.prepare;

    final listing = run.listPackages();
    await Future<void>.delayed(Duration.zero);

    expect(run.busy, isTrue);
    expect(run.doing, 'Asking the machine what it can install…');
    expect(run.output, <String>['Reading package lists...']);
    expect(run.canGoOn, isFalse);

    slow.answer.complete(ProcessResult(0, 0, '{"packages": []}', 'nothing yet'));
    await listing;
    expect(run.busy, isFalse);
    expect(run.said, 'nothing yet');
  });
}
