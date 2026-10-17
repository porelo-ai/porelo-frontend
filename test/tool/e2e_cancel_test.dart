// Linux only: it runs tool/e2e.sh in Bash and signals it.
@Tags(<String>['linux'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Holds tool/e2e.sh to stopping with the build that runs it.
///
/// A cancelled build signals only its step's shell: what that shell started gets no signal and runs
/// on, driving a rented machine, until the runner kills the orphans at the job's end. So the script
/// stops its test when one of the processes that started it is gone, and on INT or TERM.
void main() {
  late Directory scratch;
  late Directory shims;

  setUp(() {
    scratch = Directory.systemTemp.createTempSync('e2e-cancel-');
    shims = Directory('${scratch.path}/bin')..createSync();
    // Stands in for the test run: says it started, and runs until it is stopped or told otherwise.
    final xvfbRun = File('${shims.path}/xvfb-run')
      ..writeAsStringSync('#!/bin/sh\n'
          'echo \$\$ > "${scratch.path}/test.pid"\n'
          'if [ -n "\${E2E_FAKE_EXIT:-}" ]; then exit "\$E2E_FAKE_EXIT"; fi\n'
          'exec sleep 300\n');
    Process.runSync('chmod', <String>['755', xvfbRun.path]);
  });

  tearDown(() {
    final pid = File('${scratch.path}/test.pid');
    if (pid.existsSync()) Process.killPid(int.parse(pid.readAsStringSync().trim()), ProcessSignal.sigkill);
    scratch.deleteSync(recursive: true);
  });

  Map<String, String> environment({String? exit}) => <String, String>{
        'PATH': '${shims.path}:${Platform.environment['PATH']}',
        'HOME': scratch.path,
        'PORELO_E2E_HOST': 'nobody@e2e.invalid',
        'PORELO_E2E_REMOTE_SOCKET': '/run/user/0/porelo/porelod.sock',
        'E2E_FAKE_EXIT': ?exit,
      };

  Future<int> started() async {
    final pid = File('${scratch.path}/test.pid');
    for (var i = 0; i < 100 && !(pid.existsSync() && pid.readAsStringSync().trim().isNotEmpty); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(pid.existsSync(), isTrue, reason: 'the stand-in test run never started');
    return int.parse(pid.readAsStringSync().trim());
  }

  bool alive(int pid) => Process.runSync('kill', <String>['-0', '$pid']).exitCode == 0;

  Future<bool> goneWithin(int pid, Duration limit) async {
    final until = DateTime.now().add(limit);
    while (DateTime.now().isBefore(until)) {
      if (!alive(pid)) return true;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return !alive(pid);
  }

  test('the test stops within seconds once the shell that started the script is gone', () async {
    // The step's shell of a cancelled build: it ends, and nothing below it is signalled.
    final step = await Process.start('bash', <String>['-c', 'tool/e2e.sh & wait'],
        environment: environment(), includeParentEnvironment: false);
    final test = await started();
    step.kill(ProcessSignal.sigkill);
    expect(await goneWithin(test, const Duration(seconds: 5)), isTrue,
        reason: 'the test run $test was still running 5 s after the shell that started it ended');
  });

  test('the test stops within seconds when the script is told TERM', () async {
    final script = await Process.start('tool/e2e.sh', <String>[],
        environment: environment(), includeParentEnvironment: false);
    final test = await started();
    script.kill();
    expect(await goneWithin(test, const Duration(seconds: 5)), isTrue,
        reason: 'the test run $test was still running 5 s after the script was told TERM');
    expect(await script.exitCode.timeout(const Duration(seconds: 5)), 130,
        reason: 'a stopped run exits 130, never as a pass');
  });

  test('a run that ends by itself passes its exit code on', () async {
    final script = await Process.start('tool/e2e.sh', <String>[],
        environment: environment(exit: '3'), includeParentEnvironment: false);
    expect(await script.exitCode.timeout(const Duration(seconds: 20)), 3);
  });
}
