// Linux: HostRun secures lock directories with chmod.
@Tags(['linux'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

import '../bin/porelo_host.dart' show runHostCommand;
import 'host_run_test.dart' show ScriptedRemote;
import 'server_contract_test.dart' show sshKey;

void main() {
  late Directory scratch;
  late StringBuffer output;
  late StringBuffer errors;
  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('command-security-');
    output = StringBuffer();
    errors = StringBuffer();
  });
  tearDown(() => scratch.delete(recursive: true));
  List<String> down(String name, String address, {bool project = false}) => [
    'down',
    if (project) ...['--project', name, '--account', 'worker'] else ...['--host-name', name],
    '--given',
    address,
    '--host-key',
    sshKey,
  ];
  Map<String, String> getEnvironment() => {
    'XDG_STATE_HOME': scratch.path,
    'HOME': scratch.path,
    'LOCALAPPDATA': scratch.path,
  };
  // Harm: a teardown address or key must not inject known_hosts entries or SSH options.
  for (final field in ['--given', '--host-key']) {
    for (final value in ['*', '192.0.2.7\n* ssh-ed25519 AAAA', 'bad value']) {
      test('down rejects unsafe $field ${jsonEncode(value)} before SSH', () async {
        final remote = ScriptedRemote([]);
        expect(
          await runHostCommand(
            [...down('orchard', '192.0.2.7'), field, value],
            remote: remote,
            output: output,
            errors: errors,
            environment: getEnvironment(),
          ),
          Exit.refused,
        );
        expect(remote.commands, isEmpty);
      });
    }
  }
  // Harm: ambient config and disk keys must never authenticate a root teardown.
  for (final project in [false, true]) {
    test('root teardown excludes ambient identities project=$project', () async {
      final commands = <List<String>>[];
      final child = File('${scratch.path}/ok.dart');
      await child.writeAsString("import 'dart:io'; Future<void> main() async { await stdin.drain<void>(); }");
      expect(
        await runHostCommand(
          down('orchard', '192.0.2.7', project: project),
          output: output,
          errors: errors,
          environment: getEnvironment(),
          startSsh: (_, args) {
            commands.add(args);
            return Process.start(Platform.resolvedExecutable, [child.path]);
          },
        ),
        Exit.done,
      );
      expect(commands, isNotEmpty);
      for (final command in commands) {
        expect(command, containsAllInOrder(['-F', '/dev/null']));
        expect(command, contains('IdentityFile=none'));
        final effective = await Process.run('ssh', ['-G', ...command.sublist(0, command.length - 2), 'root@192.0.2.7']);
        expect(effective.exitCode, 0, reason: '${effective.stderr}');
        final lines = const LineSplitter().convert('${effective.stdout}');
        expect(lines.where((l) => l.startsWith('identityfile ')), ['identityfile none']);
        expect(lines, containsAll(['forwardagent no', 'identitiesonly no']));
      }
    });
  }
  // Harm: parallel hosts must not overwrite each other's pin or touch the user's state directory.
  for (final sameNameProject in [false, true]) {
    test('concurrent teardown pins stay distinct project collision=$sameNameProject', () async {
      final bothStarted = Completer<void>();
      final pins = <String, String>{};
      final child = File('${scratch.path}/ok.dart');
      await child.writeAsString("import 'dart:io'; Future<void> main() async { await stdin.drain<void>(); }");
      Future<int> run(String name, String address, {bool project = false}) => runHostCommand(
        down(name, address, project: project),
        output: output,
        errors: errors,
        environment: getEnvironment(),
        startSsh: (_, args) async {
          final option = args.singleWhere((a) => a.startsWith('UserKnownHostsFile='));
          final file = option.substring('UserKnownHostsFile="'.length, option.length - 1);
          pins[address] = file;
          if (pins.length == 2 && !bothStarted.isCompleted) bothStarted.complete();
          await bothStarted.future;
          expect(file, startsWith('${scratch.path}/'));
          expect(await File(file).readAsString(), '$address $sshKey\n');
          return Process.start(Platform.resolvedExecutable, [child.path]);
        },
      );
      expect(
        await Future.wait([
          run('orchard', '192.0.2.7'),
          run(sameNameProject ? 'orchard' : 'meadow', '192.0.2.8', project: sameNameProject),
        ]),
        [Exit.done, Exit.done],
      );
      expect(pins.values.toSet(), hasLength(2));
    });
  }
  // Harm: rejected commands must reach the caller's error channel with the attempted operation.
  for (final verb in ['up', 'down', 'find', 'key']) {
    test('$verb usage errors use the supplied error sink', () async {
      expect(await runHostCommand([verb, '--unknown'], errors: errors, output: output), Exit.usage);
      expect(errors.toString(), contains('porelo-host:'));
    });
  }
  test('invalid up plan reports an up refusal', () async {
    expect(
      await runHostCommand(
        ['up', '--host-name', 'Bad', '--given', '192.0.2.7', '--host-key', sshKey],
        errors: errors,
        output: output,
      ),
      Exit.refused,
    );
    expect(Step.fromLine(output.toString().trim())!.step, 'up');
  });
}
