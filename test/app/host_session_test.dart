// A stand-in `porelo-host` is a small `sh`, which only Linux has here.
@Tags(<String>['linux'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_host/porelo_host.dart';

void main() {
  late Directory scratch;
  setUp(() async => scratch = await Directory.systemTemp.createTemp('host-session-'));
  tearDown(() => scratch.delete(recursive: true));

  /// A stand-in `porelo-host` that says [lines], keeps its arguments and its standard input, and ends with [code].
  StartHostCommand saying(List<String> lines, {int code = 0, String words = ''}) =>
      (executable, arguments) => Process.start('sh', <String>[
        '-c',
        'printf "%s\\n" "\$@" > "${scratch.path}/arguments"; cat > "${scratch.path}/input"; '
            '${lines.map((l) => "printf '%s\\n' '$l'; ").join()}'
            'printf "%s" "$words" >&2; exit $code',
        'porelo-host',
        ...arguments,
      ]);

  String kept(String name) => File('${scratch.path}/$name').readAsStringSync();

  test('the steps come in as they are said, each one where it began', () async {
    final session = HostSession(
      executable: 'porelo-host',
      arguments: const <String>['--project', 'demo'],
      start: saying(<String>[
        const Step('rent', StepState.started).toLine(),
        const Step('ssh', StepState.started).toLine(),
        const Step('rent', StepState.done).toLine(),
        const Step('ssh', StepState.done).toLine(),
      ]),
    );

    await session.up();

    expect(session.state, HostRunState.done);
    expect(session.steps.map((s) => '${s.step}:${s.state.name}'), <String>['rent:done', 'ssh:done']);
    expect(kept('arguments'), 'up\n--project\ndemo\n');
  });

  test('75 is the stop, with what the person must give', () async {
    final session = HostSession(
      executable: 'porelo-host',
      arguments: const <String>[],
      start: saying(<String>[
        const Step('person', StepState.waiting, needs: <String>['drive', 'vault-new']).toLine(),
      ], code: 75),
    );

    await session.up();

    expect(session.state, HostRunState.waiting);
    expect(session.needs, <String>['drive', 'vault-new']);
    expect(session.fix, isNull, reason: 'a stop is no refusal');
  });

  test('the answers go to standard input only, never into the arguments', () async {
    final session = HostSession(
      executable: 'porelo-host',
      arguments: const <String>['--project', 'demo'],
      start: saying(<String>[const Step('vault', StepState.done).toLine()]),
    );

    await session.resume(
      const Answers(driveEmail: 'me@example.org', drivePassword: 'drive-secret', vaultPassphrase: 'vault-secret'),
    );

    expect(kept('arguments'), isNot(contains('secret')));
    expect(kept('arguments'), contains('--answers-on-stdin'));
    expect(kept('input'), contains('"drivePassword":"drive-secret"'));
    expect(kept('input'), contains('"vaultPassphrase":"vault-secret"'));
  });

  test('a refusal keeps the step\'s fix, and an ending with no step keeps the command\'s words', () async {
    final refused = HostSession(
      executable: 'porelo-host',
      arguments: const <String>[],
      start: saying(<String>[
        const Step('vault', StepState.refused, fix: 'the vault was not opened').toLine(),
      ], code: 65),
    );
    await refused.up();
    expect(refused.state, HostRunState.refused);
    expect(refused.fix, 'the vault was not opened');

    final unreachable = HostSession(
      executable: 'porelo-host',
      arguments: const <String>[],
      start: saying(const <String>[], code: 69, words: 'no route to host'),
    );
    await unreachable.up();
    expect(unreachable.state, HostRunState.unreachable);
    expect(unreachable.fix, 'no route to host');
  });
}
