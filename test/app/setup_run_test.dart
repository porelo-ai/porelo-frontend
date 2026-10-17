import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machine_setup.dart';
import 'package:porelo_frontend/src/app/setup_run.dart';

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

void main() {
  late Directory home;

  setUp(() => home = Directory.systemTemp.createTempSync('setup-run-'));
  tearDown(() => home.deleteSync(recursive: true));

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
