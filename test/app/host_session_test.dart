// A stand-in `porelo-host` is a small `sh`, which only Linux has here.
@Tags(<String>['linux'])
library;

import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_host/porelo_host.dart';

void main() {
  // Harm: a shipped build runs an environment-selected executable or work goes to the wrong host.
  test('the host command honors a stand-in only outside release builds', () {
    final shipped = Platform.isWindows
        ? '${File(Platform.resolvedExecutable).parent.path}\\porelo-host.exe'
        : '/usr/lib/porelo-frontend/porelo-host';
    const environment = {'PORELO_HOST_STANDIN': '/walk/porelo-host'};
    expect(poreloHost(environment: environment, release: false), '/walk/porelo-host');
    expect(poreloHost(environment: environment, release: true), shipped);
    expect(poreloHost(environment: const {}, release: false), shipped);
    expect(poreloHost(environment: const {'PORELO_HOST_STANDIN': ''}, release: false), shipped);
  });

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

  // Harm: a secret passes through the interface into provisioning stdin.
  test('every up closes stdin without writing and keeps the stop destination', () async {
    final commands = <List<String>>[];
    final processes = <_RecordingProcess>[];
    const stop = Step(
      'person',
      StepState.waiting,
      needs: ['drive', 'vault-new'],
      address: '203.0.113.7',
      account: 'actual-account',
    );
    final session = HostSession(
      executable: 'porelo-host',
      arguments: const ['--project', 'demo'],
      start: (_, arguments) async {
        commands.add(List.of(arguments));
        final process = _RecordingProcess(
          processes.length < 2 ? stop : const Step('up', StepState.done),
          processes.length < 2 ? Exit.waiting : Exit.done,
        );
        processes.add(process);
        return process;
      },
    );
    addTearDown(session.dispose);
    for (var run = 0; run < 3; run++) {
      await session.up();
      expect(processes.last.bytes, isEmpty, reason: 'up never receives a secret on stdin');
      expect(processes.last.closed, isTrue);
      if (run < 2) {
        expect(session.state, HostRunState.waiting);
        expect(session.address, '203.0.113.7');
        expect(session.account, 'actual-account');
        expect(session.needs, ['drive', 'vault-new']);
      }
    }
    expect(session.state, HostRunState.done);
    expect(commands, List.filled(3, ['up', '--project', 'demo']));
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

class _RecordingProcess extends Fake implements Process {
  _RecordingProcess(Step step, this.code) : output = utf8.encode('${step.toLine()}\n') {
    final input = StreamController<List<int>>();
    input.stream.listen(bytes.addAll, onDone: () => closed = true);
    sink = IOSink(input.sink);
  }
  final int code;
  final List<int> output;
  final bytes = <int>[];
  bool closed = false;
  late final IOSink sink;
  @override
  IOSink get stdin => sink;
  @override
  Stream<List<int>> get stdout => Stream.value(output);
  @override
  Stream<List<int>> get stderr => const Stream.empty();
  @override
  Future<int> get exitCode async => code;
}
