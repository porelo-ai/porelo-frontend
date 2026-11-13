// Linux only: porelo-planner is built for Linux; these start shell scripts and read its runtime directory.
@Tags(<String>['linux'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/planner.dart';
import 'package:porelo_frontend/src/app/window_log.dart';
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

  LocalPlanner client({required List<String> candidates, StartPlanner? start, Duration? wait, Duration? follow}) =>
      LocalPlanner(
        projects: () => ['demo'],
        repositories: (project) => PlannerProject('https://example.org/$project.git'),
        runtimeDirectory: runtime.path,
        candidates: candidates,
        start: start,
        wait: wait ?? const Duration(seconds: 5),
        poll: const Duration(milliseconds: 20),
        follow: follow ?? const Duration(seconds: 2),
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

    expect(serving.signals, isEmpty);
    expect(starts, isEmpty);
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

  // Harm: a close overlapping a signal lets the window exit while the planner it started is still being ended.
  test('an end asked while one runs waits for the same end', () async {
    final started = PlannerProcess(ignoresTerm: true);
    final local = client(candidates: [await program()], start: starting(started));
    await local.reach();

    final first = local.end();
    await local.end();

    expect(started.ended, isTrue, reason: 'the second end answers only once the planner ended');
    expect(started.signals, [ProcessSignal.sigterm, ProcessSignal.sigkill]);
    await first;
  });

  // Harm: a planner the window started and then lost sight of keeps running beside the one it starts next.
  test('a planner the window started again ends the one it started before', () async {
    final first = PlannerProcess();
    final second = PlannerProcess();
    final processes = [first, second];
    var starts = 0;
    final local = client(
      candidates: [await program()],
      follow: const Duration(milliseconds: 20),
      start: (_, _) async {
        await announce(token: 'token-of-start-${starts + 1}');
        return processes[starts++];
      },
    );
    await local.reach();
    await addressFile().delete();

    await until(() => starts == 2 && local.providers.isNotEmpty);

    expect(first.signals, [ProcessSignal.sigterm]);
    expect(second.signals, isEmpty);
  });

  // Harm: the window's end during a restart returns while the old planner still runs, and a new one is started after
  // the window ended, so either outlives it and holds the address file.
  test('an end asked while a restart stops the old planner waits for it and starts no new one', () async {
    // It ignores SIGTERM, so its stop takes the bounded wait before SIGKILL.
    final first = PlannerProcess(ignoresTerm: true);
    var starts = 0;
    final local = client(
      candidates: [await program()],
      follow: const Duration(milliseconds: 20),
      start: (_, _) async {
        starts++;
        await announce(token: 'token-of-start-$starts');
        return starts == 1 ? first : PlannerProcess();
      },
    );
    await local.reach();
    await addressFile().delete();
    await until(() => first.signals.isNotEmpty);

    await local.end();

    expect(first.ended, isTrue, reason: 'the end answers only once the old planner ended');
    await local.reach();
    expect(starts, 1, reason: 'no planner is started once the end began');
  });

  // Harm: a planner the window started that moved to another port outlives the window.
  test('a planner the window started that wrote a new address is still ended', () async {
    final started = PlannerProcess();
    final local = client(
      candidates: [await program()],
      start: starting(started),
      follow: const Duration(milliseconds: 20),
    );
    await local.reach();
    final before = local.providers.single.source;
    await announce(token: 'token-after-a-restart-of-its-server');
    await until(() => local.providers.isNotEmpty && !identical(local.providers.single.source, before));

    await local.end();

    expect(started.signals, [ProcessSignal.sigterm]);
  });

  group('the output of a planner the window started', () {
    late Directory logs;
    late WindowLog before;

    setUp(() async {
      logs = await Directory.systemTemp.createTemp('planner-end-logs-');
      before = windowLog;
      windowLog = WindowLog(logs.path, level: ValueNotifier(LogLevel.debug), keepPrivate: (_) async {});
    });

    tearDown(() async {
      windowLog = before;
      await logs.delete(recursive: true);
    });

    List<String> logged() => [
      for (final line in File(
        '${logs.path}/${WindowLog.fileName}',
      ).let((file) => file.existsSync() ? file.readAsLinesSync() : const <String>[]))
        if (line.contains('porelo-planner: '))
          line.substring(line.indexOf('porelo-planner: ') + 'porelo-planner: '.length),
    ];

    // Harm: a planner whose output nobody reads blocks once the pipe is full, and stops answering.
    test('is read to its end, far past what a pipe holds', () async {
      var pulled = 0;
      Stream<List<int>> lines(String name) async* {
        for (var i = 0; i < 4096; i++) {
          pulled++;
          yield utf8.encode('$name line $i of a planner that talks a lot ${'.' * 200}\n');
        }
      }

      final started = PlannerProcess(stdout: lines('out'), stderr: lines('err'));
      final local = client(candidates: [await program()], start: starting(started));
      await local.reach();
      await until(() => pulled == 2 * 4096);
      await pumpEventQueue();

      final said = logged();
      expect(said.where((line) => line.startsWith('out line ')), hasLength(4096));
      expect(said.where((line) => line.startsWith('err line ')), hasLength(4096));
    });

    // Harm: a planner that writes without ever ending a line has the window hold all of it.
    test('is cut into lines of at most 64 KiB where it ends none', () async {
      final output = StreamController<List<int>>();
      final started = PlannerProcess(stdout: output.stream);
      final local = client(candidates: [await program()], start: starting(started));
      await local.reach();

      for (var i = 0; i < 200; i++) {
        output.add(utf8.encode('x' * 1024));
      }
      await pumpEventQueue();
      final whileUnended = logged();
      output.add(utf8.encode('\nlast\n'));
      await output.close();
      await pumpEventQueue();

      expect(whileUnended, [for (var i = 0; i < 3; i++) 'x' * plannerOutputLine]);
      expect(logged(), [
        for (var i = 0; i < 3; i++) 'x' * plannerOutputLine,
        'x' * (200 * 1024 - 3 * plannerOutputLine),
        'last',
      ]);
    });
  });

  group('how a planner the window started is ended', () {
    late Directory logs;
    late WindowLog before;

    setUp(() async {
      logs = await Directory.systemTemp.createTemp('planner-end-logs-');
      before = windowLog;
      windowLog = WindowLog(logs.path, level: ValueNotifier(LogLevel.debug), keepPrivate: (_) async {});
    });

    tearDown(() async {
      windowLog = before;
      await logs.delete(recursive: true);
    });

    List<String> hardEnds() => [
      for (final line in File(
        '${logs.path}/${WindowLog.fileName}',
      ).let((file) => file.existsSync() ? file.readAsLinesSync() : const <String>[]))
        if (line.contains(' WARN ') && line.contains('ended hard')) line,
    ];

    /// A planner as the window starts one: it writes its address where the test reads it and records in [record] its
    /// process number, then how it ended - by its input closing where [endsWithItsInput], [takes] seconds after it
    /// closed, or on SIGTERM.
    Future<String> standIn(String record, {required bool endsWithItsInput, int takes = 0}) => program(
      '''
echo "\$\$" > '$record'
dir='${runtime.path}/porelo-planner'
${endsWithItsInput ? 'exec 3<&0\ncat <&3 > /dev/null &\nreader=\$!' : 'reader='}
trap 'kill \$reader 2>/dev/null; echo signalled >> "$record"; rm -f "\$dir/planner.json"; exit 0' TERM
mkdir -p "\$dir" && chmod 700 "\$dir"
printf '{"port":${server.port},"token":"token-of-the-script"}' > "\$dir/planner.json.new"
chmod 600 "\$dir/planner.json.new" && mv "\$dir/planner.json.new" "\$dir/planner.json"
${endsWithItsInput ? 'wait \$reader\nsleep $takes\necho "input closed" >> \'$record\'\nrm -f "\$dir/planner.json"' : 'while :; do sleep 0.1; done'}''',
    );

    /// Stops whatever the window left running of the stand-in that recorded into [record], so no script outlives the
    /// test.
    void stopAfterwards(String record) => addTearDown(() async {
      final lines = await File(record).readAsLines().catchError((_) => <String>[]);
      if (lines.isNotEmpty) Process.killPid(int.parse(lines.first), ProcessSignal.sigkill);
    });

    LocalPlanner onWindows(String program, {Duration? inputEndWait}) => LocalPlanner(
      projects: () => ['demo'],
      repositories: (project) => PlannerProject('https://example.org/$project.git'),
      candidates: [program],
      environment: {'LOCALAPPDATA': runtime.path},
      // On Windows the planner's package reads LOCALAPPDATA itself; here it reads the test's folder.
      open: (projects, {runtimeDirectory}) =>
          HttpPlanningSource.fromAddressFile(projects, runtimeDirectory: runtime.path),
      wait: const Duration(seconds: 5),
      poll: const Duration(milliseconds: 20),
      onWindows: true,
      inputEndWait: inputEndWait ?? const Duration(seconds: 5),
    )..let(clients.add);

    // Harm: on Windows a planner that would have ended by itself is ended hard and loses what it was writing.
    test('on Windows a planner that ends when its input closes is not ended hard', () async {
      final record = '${bin.path}/record';
      final local = onWindows(await standIn(record, endsWithItsInput: true));
      stopAfterwards(record);
      await local.reach();
      await local.startNow();
      expect(local.notReached, isNull, reason: 'the started stand-in wrote its address');

      await local.end();

      expect((await File(record).readAsLines()).skip(1), ['input closed'], reason: 'it ended by its input alone');
      expect(hardEnds(), isEmpty);
    });

    // Harm: on Windows a planner still finishing its stop is ended hard and loses what it was writing.
    test(
      'on Windows a planner that takes a while to end after its input closes, within the wait, is not ended hard',
      () async {
        final record = '${bin.path}/record';
        final local = onWindows(
          await standIn(record, endsWithItsInput: true, takes: 1),
          inputEndWait: const Duration(seconds: 3),
        );
        stopAfterwards(record);
        await local.reach();
        await local.startNow();
        expect(local.notReached, isNull, reason: 'the started stand-in wrote its address');

        await local.end();

        expect((await File(record).readAsLines()).skip(1), ['input closed'], reason: 'it ended by itself, late');
        expect(hardEnds(), isEmpty);
      },
    );

    // Harm: on Windows a planner that does not end when asked outlives the window and holds the address file, a hard
    // end nobody is told of hides why its work was lost, and one that comes early cuts a stop short.
    test('on Windows a planner that ignores its input is ended hard after the wait, and the log says so', () async {
      const wait = Duration(milliseconds: 500);
      final record = '${bin.path}/record';
      final local = onWindows(await standIn(record, endsWithItsInput: false), inputEndWait: wait);
      stopAfterwards(record);
      await local.reach();
      await local.startNow();
      expect(local.notReached, isNull, reason: 'the started stand-in wrote its address');

      final ending = Stopwatch()..start();
      await local.end();

      expect(ending.elapsed, greaterThanOrEqualTo(wait), reason: 'ended hard no earlier than the wait');
      final lines = await File(record).readAsLines();
      expect(Directory('/proc/${lines.first}').existsSync(), isFalse, reason: 'it no longer runs');
      expect(lines.skip(1), isEmpty, reason: 'ended hard, never asked by a signal Windows does not have');
      expect(hardEnds(), hasLength(1));
    });

    // Harm: on Linux a planner the window started is left to an input the window holds open, and outlives it.
    test('on Linux a planner the window started is still ended with SIGTERM, its input left open', () async {
      final record = '${bin.path}/record';
      final local = LocalPlanner(
        projects: () => ['demo'],
        repositories: (project) => PlannerProject('https://example.org/$project.git'),
        runtimeDirectory: runtime.path,
        candidates: [await standIn(record, endsWithItsInput: true)],
        wait: const Duration(seconds: 5),
        poll: const Duration(milliseconds: 20),
        onWindows: false,
      )..let(clients.add);
      stopAfterwards(record);
      await local.reach();
      expect(local.notReached, isNull, reason: 'the started stand-in wrote its address');

      await local.end();

      expect((await File(record).readAsLines()).skip(1), ['signalled']);
      expect(hardEnds(), isEmpty);
    });
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
  R let<R>(R Function(T) use) => use(this);
}
