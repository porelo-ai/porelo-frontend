// Linux: down takes a POSIX lock and checks its private directory with chmod.
@Tags(['linux'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

import '../bin/porelo_host.dart' as cli;
import 'host_run_test.dart' show ScriptedRemote;

void main() {
  late Directory directory;
  setUp(() async => directory = await Directory.systemTemp.createTemp('down-cli-'));
  tearDown(() => directory.delete(recursive: true));

  Future<int> invoke(List<String> options, ScriptedRemote remote, {StringBuffer? output}) => cli.runHostCommand(
    [
      'down',
      '--host-name',
      'orchard',
      '--given',
      '192.0.2.7',
      '--host-key',
      'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwc',
      ...options,
    ],
    remote: remote,
    output: output ?? StringBuffer(),
    errors: StringBuffer(),
    environment: {'XDG_STATE_HOME': directory.path},
  );

  // Harm: an unchecked login reaches a remote root shell and can delete an unintended account.
  for (final login in [
    '',
    'Alice',
    '-alice',
    'alice_bob',
    'a' * 33,
    'alice;id',
    'alice\n',
    'porelo',
    'porelo-worker',
  ]) {
    test('invalid purge login ${jsonEncode(login)} refuses before any connection', () async {
      final remote = ScriptedRemote([]);
      expect(await invoke(['--purge', login], remote), Exit.usage);
      expect(remote.commands, isEmpty);
      expect(directory.listSync(), isEmpty, reason: 'argument validation precedes state and connection setup');
    });
  }

  // Harm: incompatible read-only, purge and loss-confirmed modes must not bypass one another's checks.
  for (final options in [
    ['--purge', 'alice', '--give-back-anyway'],
    ['--memberships', '--purge', 'alice'],
    ['--memberships', '--give-back-anyway'],
    ['--purge'],
  ]) {
    test('incompatible or incomplete options $options refuse before any connection', () async {
      final remote = ScriptedRemote([]);
      expect(await invoke(options, remote), Exit.usage);
      expect(remote.commands, isEmpty);
      expect(directory.listSync(), isEmpty);
    });
  }

  // Harm: silently dropping repeated purge options leaves memberships behind and blocks clean teardown.
  test('the CLI passes each named purge to teardown once', () async {
    final remote = ScriptedRemote([]);
    expect(await invoke(['--purge', 'alice', '--purge', 'bob', '--purge', 'alice'], remote), Exit.done);
    expect(
      remote.commands.where(
        (command) => command.startsWith(
          'env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin LANG=C.UTF-8 /usr/sbin/porelo-host person purge ',
        ),
      ),
      [
        'env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin LANG=C.UTF-8 /usr/sbin/porelo-host person purge alice',
        'env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin LANG=C.UTF-8 /usr/sbin/porelo-host person purge bob',
      ],
    );
  });

  // Harm: a status-only option must never fall through to teardown or a forced release.
  test('memberships reads through the CLI without starting a down play', () async {
    final remote = ScriptedRemote([]);
    final output = StringBuffer();
    expect(await invoke(['--memberships'], remote, output: output), Exit.done);
    expect(remote.commands, [
      'env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin LANG=C.UTF-8 /usr/sbin/porelo-host org status --json',
    ]);
    expect(LineSplitter.split(output.toString()).map(Step.fromLine).last!.step, 'org-status');
  });

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
      'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwc',
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
