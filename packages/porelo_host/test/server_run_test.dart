// Linux only: exercises POSIX file locks and process termination across Dart children; HostRun invokes chmod.
@Tags(['linux'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

void main() {
  // Harm: a concurrent teardown can delete a server while another command owns its rental.
  test('the rental lock prevents a competing process and is released when its owner exits', () async {
    final scratch = await Directory.systemTemp.createTemp('host-lock-');
    final children = <Process>[];
    addTearDown(() async {
      for (final child in children) {
        child.kill();
        await child.exitCode;
      }
      await scratch.delete(recursive: true);
    });
    Future<Process> start(String name, {bool hold = false, String project = 'demo'}) async {
      final child = await Process.start(
        Platform.resolvedExecutable,
        ['test/support/host_lock_process.dart', scratch.path, name, 'down', project, hold ? 'hold' : 'go'],
        environment: {'XDG_STATE_HOME': scratch.path, 'LOCALAPPDATA': scratch.path},
      );
      children.add(child);
      return child;
    }

    final owner = await start('owner', hold: true);
    final ownerOut = owner.stdout.drain<void>();
    final ownerErr = owner.stderr.transform(utf8.decoder).join();
    await Future.any([
      (() async {
        while (!await File('${scratch.path}/owner-find').exists()) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      })(),
      owner.exitCode.then((code) async => throw StateError('The lock owner exited $code: ${await ownerErr}')),
    ]).timeout(const Duration(seconds: 45));
    final contender = await start('contender');
    final output = contender.stdout.transform(utf8.decoder).join();
    final errors = contender.stderr.transform(utf8.decoder).join();
    expect(await contender.exitCode.timeout(const Duration(seconds: 45)), Exit.waiting, reason: await errors);
    expect(
      File('${scratch.path}/contender-find').existsSync(),
      isFalse,
      reason: 'the losing process must never reach the provider',
    );
    expect(const LineSplitter().convert(await output).map(Step.fromLine).single?.step, 'lock');
    owner.kill();
    await owner.exitCode;
    await ownerOut;
    await ownerErr;
    final after = await start('after');
    final afterOutput = after.stdout.drain<void>();
    final afterErrors = after.stderr.drain<void>();
    expect(await after.exitCode.timeout(const Duration(seconds: 45)), Exit.done);
    await afterOutput;
    await afterErrors;
    expect(File('${scratch.path}/after-find').existsSync(), isTrue);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
