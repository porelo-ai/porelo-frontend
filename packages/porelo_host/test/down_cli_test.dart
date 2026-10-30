// Linux: down takes a POSIX lock and checks its private directory with chmod.
@Tags(['linux'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  setUp(() async => directory = await Directory.systemTemp.createTemp('down-cli-'));
  tearDown(() => directory.delete(recursive: true));

  Future<ProcessResult> down(String name, {bool force = false, bool configured = true}) => Process.run(
    Platform.resolvedExecutable,
    [
      'bin/porelo_host.dart',
      'down',
      '--host-name',
      name,
      '--given',
      '192.0.2.7',
      '--host-key',
      'ssh-ed25519 AAAA',
      if (force) '--give-back-anyway',
    ],
    includeParentEnvironment: false,
    environment: {
      'PATH': '/usr/bin:/bin',
      'DASH__SUPPRESS_ANALYTICS': 'true',
      'TMPDIR': Directory.systemTemp.path,
      'XDG_STATE_HOME': directory.path,
      if (configured) 'XDG_CONFIG_HOME': directory.path,
    },
  );

  // Harm: invalid recovery input must yield the refusal protocol rather than an unforeseen crash.
  test('an invalid host name yields a structured refusal before any SSH configuration', () async {
    final result = await down('../other');
    expect(result.exitCode, Exit.refused, reason: '${result.stderr}');
    final steps = LineSplitter.split(result.stdout.toString()).map(Step.fromLine).toList();
    expect(steps, isNotEmpty);
    expect(steps.every((step) => step != null), isTrue);
    expect(steps.last!.state, StepState.refused);
  });

  // Harm: losing the local config folder must not prevent explicit release of a billed rental.
  test('forced give-back needs no SSH config directory or SSH process', () async {
    final result = await down('orchard', force: true, configured: false);
    expect(result.exitCode, Exit.done, reason: '${result.stderr}');
    final steps = LineSplitter.split(result.stdout.toString()).map(Step.fromLine).toList();
    expect(steps.last!.step, 'give-back');
    expect(steps.last!.state, StepState.done);
  });

  // Harm: an unavailable config directory must refuse safely while keeping the rental.
  test('ordinary teardown without a config directory yields a structured refusal', () async {
    final result = await down('orchard', configured: false);
    expect(result.exitCode, Exit.refused, reason: '${result.stderr}');
    final steps = LineSplitter.split(result.stdout.toString()).map(Step.fromLine).toList();
    expect(steps.last!.state, StepState.refused);
  });
}
