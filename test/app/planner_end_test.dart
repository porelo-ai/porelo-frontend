// Linux only: porelo-planner is built for Linux; these start shell scripts and read its runtime directory.
@Tags(<String>['linux'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/planner.dart';
import 'package:porelo_planning/porelo_planning.dart';

import '../support/planner_process.dart';

/// The planner a window started ends with the window; one it found serving, or one that took the started one's place,
/// is left running.
void main() {
  late Directory runtime;
  late Directory bin;
  late HttpServer server;
  final clients = <LocalPlanner>[];

  setUp(() async {
    runtime = await Directory.systemTemp.createTemp('planner-end-runtime-');
    // Closed to others, as /run/user is: the planner's package refuses a runtime directory others may write.
    await Process.run('chmod', ['700', runtime.path]);
    bin = await Directory.systemTemp.createTemp('planner-end-bin-');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      await request.drain<void>();
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
    });
  });

  tearDown(() async {
    for (final client in clients) {
      client.dispose();
    }
    clients.clear();
    await server.close(force: true);
    await runtime.delete(recursive: true);
    await bin.delete(recursive: true);
  });

  File addressFile() => File('${runtime.path}/porelo-planner/planner.json');

  /// Writes the address file as the planner does: owner-only, in an owner-only directory, in one step.
  Future<void> announce({String token = 'token-of-the-started-one'}) async {
    final directory = await Directory('${runtime.path}/porelo-planner').create(recursive: true);
    await Process.run('chmod', ['700', directory.path]);
    final written = File('${directory.path}/planner.json.new');
    await written.writeAsString(jsonEncode({'port': server.port, 'token': token}));
    await Process.run('chmod', ['600', written.path]);
    await written.rename(addressFile().path);
  }

  /// A program the planner could be, which nothing ever runs where the start is the test's.
  Future<String> program([String script = 'exit 1']) async {
    final file = File('${bin.path}/porelo-planner');
    await file.writeAsString('#!/bin/sh\n$script\n');
    await Process.run('chmod', ['700', file.path]);
    return file.path;
  }

  LocalPlanner client({required List<String> candidates, StartPlanner? start, Duration? wait}) => LocalPlanner(
    projects: () => ['demo'],
    repositories: (project) => PlannerProject('https://example.org/$project.git'),
    runtimeDirectory: runtime.path,
    candidates: candidates,
    start: start,
    wait: wait ?? const Duration(seconds: 5),
    poll: const Duration(milliseconds: 20),
  )..let(clients.add);

  /// A start that hands [process] and has it write its address, as a planner does once it listens.
  StartPlanner starting(PlannerProcess process, {List<String>? starts}) => (executable, _) async {
    starts?.add(executable);
    await announce();
    return process;
  };

  // Harm: a planner the window started outlives it and holds the address file, so the next planner cannot start.
  test('a planner is started to end with its input, which the window holds open until it ends the planner', () async {
    final record = '${bin.path}/record';
    // As the planner behaves under its option: it reads its input until it closes and stops on SIGTERM, either way
    // deleting its address file, which it writes once both are set up.
    final path = await program('''
echo "\$\$" > '$record'
printf '%s\\n' "\$@" >> '$record'
dir="\$XDG_RUNTIME_DIR/porelo-planner"
exec 3<&0
cat <&3 > /dev/null &
reader=\$!
trap 'kill \$reader; echo stopped >> "$record"; rm -f "\$dir/planner.json"; exit 0' TERM
mkdir -p "\$dir" && chmod 700 "\$dir"
printf '{"port":${server.port},"token":"token-of-the-script"}' > "\$dir/planner.json.new"
chmod 600 "\$dir/planner.json.new" && mv "\$dir/planner.json.new" "\$dir/planner.json"
wait \$reader
echo "input closed" >> '$record'
rm -f "\$dir/planner.json"''');
    final local = client(candidates: [path]);
    addTearDown(() async {
      // Whatever the window left running is stopped by the test, so no script outlives it.
      final lines = await File(record).readAsLines().catchError((_) => <String>[]);
      if (lines.isNotEmpty) Process.killPid(int.parse(lines.first));
    });

    await local.reach();
    expect(local.notReached, isNull, reason: 'the started script wrote its address');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final whileRunning = await File(record).readAsLines();

    expect(whileRunning.skip(1), [plannerEndsWithInput], reason: 'started with the option alone');
    expect(addressFile().existsSync(), isTrue, reason: 'its input is still open, so it still runs');

    await local.end();
    await until(() => !addressFile().existsSync());
    expect(await File(record).readAsLines(), contains('stopped'));
  });

  // Harm: a planner the window started outlives it, so the next planner cannot start.
  test('a planner the window started is ended with SIGTERM', () async {
    final started = PlannerProcess();
    final local = client(candidates: [await program()], start: starting(started));
    await local.reach();

    await local.end();

    expect(started.signals, [ProcessSignal.sigterm]);
    expect(started.ended, isTrue);
  });

  // Harm: a planner the window started outlives it where it wrote its address just as the window looked.
  test('a planner the window started that wrote its address while the window looked is ended', () async {
    final started = PlannerProcess();
    var opened = 0;
    final local = LocalPlanner(
      projects: () => ['demo'],
      repositories: (project) => PlannerProject('https://example.org/$project.git'),
      runtimeDirectory: runtime.path,
      candidates: [await program()],
      start: (_, _) async => started,
      // The address appears after the window read it and before it opened it.
      open: (projects, {runtimeDirectory}) async {
        if (++opened == 2) await announce();
        return HttpPlanningSource.fromAddressFile(projects, runtimeDirectory: runtimeDirectory);
      },
      poll: const Duration(milliseconds: 20),
    )..let(clients.add);
    await local.reach();
    expect(local.notReached, isNull);

    await local.end();

    expect(started.signals, [ProcessSignal.sigterm]);
  });

  // Harm: the window ends a planner it did not start, which serves the account's other windows and tools.
  test('a planner the window found serving is left running', () async {
    await announce();
    final serving = PlannerProcess();
    final starts = <String>[];
    // Were the window to start one beside it anyway, this start would hand it the serving planner.
    final local = client(
      candidates: [await program()],
      start: starting(serving, starts: starts),
    );
    await local.reach();

    await local.end();

    expect(starts, isEmpty);
    expect(serving.signals, isEmpty);
    expect(addressFile().existsSync(), isTrue);
  });

  // Harm: the window ends a planner that took the started one's place, which the window did not start.
  test('a planner whose address file names another address is left running', () async {
    final started = PlannerProcess();
    final local = client(candidates: [await program()], start: starting(started));
    await local.reach();
    await announce(token: 'token-of-another-planner');

    await local.end();

    expect(started.signals, isEmpty);
  });

  // Harm: a planner stuck in its stop outlives the window and holds the address file.
  test('a planner the window started that ignores SIGTERM is killed', () async {
    final started = PlannerProcess(ignoresTerm: true);
    final local = client(candidates: [await program()], start: starting(started));
    await local.reach();

    await local.end();

    expect(started.signals, [ProcessSignal.sigterm, ProcessSignal.sigkill]);
    expect(started.ended, isTrue);
  });

  // Harm: a signal reaches whatever process took the number of a planner that already ended.
  test('a planner the window started that ended by itself is sent no signal', () async {
    final started = PlannerProcess();
    final local = client(candidates: [await program()], start: starting(started));
    await local.reach();
    started.endWith(0);
    await Future<void>.delayed(Duration.zero);

    await local.end();

    expect(started.signals, isEmpty);
  });

  // Harm: a planner that refuses to start, as one that does not know the option, leaves the place waiting in silence.
  test('a started planner that ends before it writes its address is said with its exit code at once', () async {
    final local = client(
      candidates: [await program()],
      start: (_, _) async => PlannerProcess()..endWith(64),
      wait: const Duration(seconds: 10),
    );
    final waited = Stopwatch()..start();

    await local.reach();

    expect(waited.elapsed, lessThan(const Duration(seconds: 5)));
    expect(local.notReached, contains('exit code 64'));
  });
}

/// Waits until [condition] holds, failing after five seconds.
Future<void> until(bool Function() condition) async {
  final waited = Stopwatch()..start();
  while (!condition()) {
    if (waited.elapsed > const Duration(seconds: 5)) fail('the condition never held');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

extension<T> on T {
  void let(void Function(T) use) => use(this);
}
