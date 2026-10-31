import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/conpty.dart';
import 'package:porelo_frontend/src/app/pty.dart';

void main() {
  // Harm: a Windows terminal's close returning while its program still runs, so what waits on that close, a Forget or
  // a second attempt, goes ahead while the program may still commit.
  test('closing a Windows console waits for its program to end', () async {
    final ended = Completer<int>();
    var letGo = false;
    var closed = false;

    final closing = ConPty.letGoAndWait(() async => letGo = true, ended.future).then((_) => closed = true);
    await pumpEventQueue();

    expect([letGo, closed], [true, false], reason: 'the console is let go, and its program has not ended');
    ended.complete(0);
    await closing;
    expect(closed, isTrue);
  });

  // Harm: a program that outlived the bound after its close taken as ended, on Windows as on Linux.
  test('a program that outlives its close is said still running, with its end to wait for', () async {
    final ended = Completer<int>();

    final outlived = await ConPty.letGoAndWait(
      () async {},
      ended.future,
      bound: const Duration(milliseconds: 10),
    ).then<Object?>((_) => null, onError: (Object error) => error);

    expect(outlived, isA<TerminalStillRunning>());
    ended.complete(70);
    expect(await (outlived! as TerminalStillRunning).ended, 70);
  });

  // Harm: a console whose letting go takes long counted against no bound, so its close waits a whole bound more after
  // it before the program is said still running, or for ever where letting go never ends.
  test('the bound runs from before the console is let go', () async {
    const bound = Duration(milliseconds: 300);
    final ended = Completer<int>();
    final watch = Stopwatch()..start();

    final outcome = await ConPty.letGoAndWait(
      () => Future<void>.delayed(bound * 4),
      ended.future,
      bound: bound,
    ).then<Object?>((_) => null, onError: (Object error) => error);

    expect(outcome, isA<TerminalStillRunning>());
    expect(watch.elapsed, lessThan(bound * 2), reason: 'the bound passed while the console was let go');
  });

  ({ConsoleRelease release, List<String> calls}) released({
    required bool? jobEnds,
    Future<void> Function()? closeAway,
    Duration lastResort = const Duration(milliseconds: 20),
  }) {
    final calls = <String>[];
    final release = ConsoleRelease(
      closeInput: () => calls.add('close input'),
      lastResort: lastResort,
      endJob: jobEnds == null
          ? null
          : () {
              calls.add('end job');
              return jobEnds;
            },
      closeJob: () => calls.add('close job'),
      closeConsole: () => calls.add('close console here'),
      closeConsoleAway: closeAway ?? () async => calls.add('close console away'),
      closeProcess: () => calls.add('close process'),
    );
    return (release: release, calls: calls);
  }

  // Harm: a console closed on the interface's own isolate, which waits on what still runs in it and freezes the window
  // past every bound, for ever where it never returns.
  test('a console whose job cannot be ended is closed off this isolate', () async {
    for (final jobEnds in [false, null]) {
      final console = released(jobEnds: jobEnds);

      await console.release.letGo();

      expect(console.calls, isNot(contains('close console here')), reason: 'job ends: $jobEnds');
      expect(console.calls, contains('close console away'), reason: 'job ends: $jobEnds');
    }
  });

  // Harm: the job's handle closed under the waiter that asks it whether its processes have ended, which then never
  // hears they did, so the program counts as running for good.
  test('the job stays open until the program was seen to end', () async {
    final console = released(jobEnds: false);

    await console.release.letGo();
    expect(console.calls, isNot(contains('close job')), reason: 'the waiter still asks the job');

    console.release.close();
    expect(console.calls.where((call) => call == 'close job'), hasLength(1));
    expect(console.calls.where((call) => call.startsWith('close console')), hasLength(1), reason: 'closed once');
  });

  // Harm: a console whose close on an isolate of its own failed counted as closed, so it is never closed and its output
  // never ends; or left unclosed after its program ended, so the close waits out its bound and says a false still
  // running; or closed on the interface's own isolate while something may still run in it, freezing the window.
  test('a console whose close away failed is closed here once its program ended, and only once', () async {
    final failing = Completer<void>();
    final console = released(jobEnds: false, closeAway: () => failing.future);

    final letGo = console.release.letGo();
    expect(console.release.closed, isFalse, reason: 'not closed before it was');
    failing.completeError(StateError('no isolate'));
    await pumpEventQueue();
    console.release.close();
    expect(console.calls.where((call) => call == 'close console here'), hasLength(1), reason: 'its program ended');
    await letGo;

    expect(console.calls.where((call) => call.startsWith('close console')), hasLength(1), reason: 'closed once');
    expect(console.release.closed, isTrue);
  });

  test('a console whose close away failed while its program runs is closed away again, never here', () async {
    var attempts = 0;
    final calls = <String>[];
    final console = released(
      jobEnds: false,
      closeAway: () async {
        if (++attempts == 1) throw StateError('no isolate');
        calls.add('close console away');
      },
    );

    await console.release.letGo();

    expect(attempts, 2, reason: 'tried away once more after the bound');
    expect(console.calls, isNot(contains('close console here')));
    expect(console.release.closed, isTrue);
    console.release.close();
    expect(console.calls, isNot(contains('close console here')), reason: 'closed once');
  });

  // Harm: a throw in one step of the console's release skipping the rest, so the program's handle, its job or its
  // console leaks with every terminal.
  test('every step of the release runs whatever the one before it threw', () {
    final calls = <String>[];
    final release = ConsoleRelease(
      closeInput: () => throw StateError('input'),
      endJob: null,
      closeJob: () => throw StateError('job'),
      closeConsole: () => throw StateError('console'),
      closeConsoleAway: () async {},
      closeProcess: () => calls.add('close process'),
    );

    release.close();

    expect(calls, ['close process']);
    expect(release.closed, isTrue);
  });

  // Harm: the way input reaches a console left open after its program ended, a handle leaked for each terminal, or
  // closed twice when the terminal is closed from this side too.
  test('the input is closed once the program ended, and only once', () async {
    final ended = released(jobEnds: true);
    ended.release.close();
    expect(ended.calls.where((call) => call == 'close input'), hasLength(1));

    final both = released(jobEnds: true);
    both.release.endInput();
    await both.release.letGo();
    both.release.close();
    expect(both.calls.where((call) => call == 'close input'), hasLength(1));
  });

  // Harm: a job that cannot be asked holding the program's end for good, though its own handle says it ended; or the
  // console closed at the program's end under a child it started that still writes.
  test('a program in no job, or one that cannot be asked, ends alone, never whole', () {
    ({int code, bool whole})? ended({required bool process, required int? Function()? job}) =>
        switch (ConPty.endedFrom(processEnded: () => process, activeInJob: job, exitCode: () => 3)) {
          final end? => (code: end.code, whole: end.whole),
          null => null,
        };

    expect(ended(process: true, job: () => null), (code: 3, whole: false), reason: 'the job could not be asked');
    expect(ended(process: true, job: () => 1), isNull, reason: 'a process of its job still runs');
    expect(ended(process: true, job: () => 0), (code: 3, whole: true));
    expect(ended(process: true, job: null), (code: 3, whole: false), reason: 'no job');
    expect(ended(process: false, job: () => null), isNull);
  });

  test('a program that ended alone keeps its console open until its output ended', () async {
    var closed = 0;
    final drain = Completer<SendPort>();
    final output = StreamController<List<int>>.broadcast();
    final ended = Completer<int>();
    ConPty.watch(
      closeConsole: () => closed++,
      output: output,
      ended: ended,
      read: (to) async => drain.complete(to),
      wait: (to) async => to.send(const ProgramEnd(3, whole: false)),
      endedNow: () => null,
    );

    await pumpEventQueue();
    expect([closed, ended.isCompleted], [0, false], reason: 'a child it started may still write');
    (await drain.future).send('drained');
    expect(await ended.future.timeout(const Duration(seconds: 5)), 3);
    expect(closed, 1);
  });

  // Harm: a reader or waiter that throws as it is started raising an error nobody handles, and the end never said.
  test('a reader or waiter that throws as it starts counts as not started', () async {
    final output = StreamController<List<int>>.broadcast();
    final ended = Completer<int>();
    var asked = 0;
    ConPty.watch(
      closeConsole: () {},
      output: output,
      ended: ended,
      read: (to) => throw StateError('no reader'),
      wait: (to) => throw StateError('no waiter'),
      endedNow: () => ++asked < 2 ? null : const ProgramEnd(3, whole: true),
      poll: const Duration(milliseconds: 5),
    );

    expect(await ended.future.timeout(const Duration(seconds: 5)), 3);
  });

  // Harm: the first pipe of a terminal left open when the second could not be made, two handles leaked each time.
  test('a pipe made before one that failed is closed', () {
    final made = <({int read, int write})?>[(read: 1, write: 2), null];
    final closed = <int>[];

    final pipes = ConPty.openPipes(() => made.removeAt(0), closed.add);

    expect(pipes, isNull);
    expect(closed, unorderedEquals([1, 2]));
  });

  // Harm: the waiter asking twice for an end it was told once, and dying on the second answer, so the end is never said.
  test('the waiter takes the end it was told, asking once per turn', () {
    final answers = <ProgramEnd?>[null, const ProgramEnd(3, whole: true), null];
    var asked = 0;

    final end = ConPty.waitUntilEnded(() => answers[asked++], () {});

    expect([end.code, asked], [3, 2]);
  });

  ({StreamController<List<int>> output, Completer<int> ended}) watched({
    required Future<Object?> Function(SendPort to) read,
    required Future<Object?> Function(SendPort to) wait,
    ProgramEnd? Function()? endedNow,
  }) {
    final output = StreamController<List<int>>.broadcast();
    final ended = Completer<int>();
    ConPty.watch(
      closeConsole: () {},
      output: output,
      ended: ended,
      read: read,
      wait: wait,
      endedNow: endedNow ?? () => null,
      poll: const Duration(milliseconds: 5),
    );
    return (output: output, ended: ended);
  }

  // Harm: a program nothing could start waiting for said ended at once, so a Forget or a second attempt goes ahead while
  // it may still commit.
  test('a program nothing waits for counts as running until it is seen gone', () async {
    var gone = false;
    final watching = watched(
      read: (to) async {
        to.send(Uint8List.fromList([0x41]));
        throw StateError('no reader');
      },
      wait: (to) async => throw StateError('no waiter'),
      endedNow: () => gone ? const ProgramEnd(3, whole: true) : null,
    );

    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(watching.ended.isCompleted, isFalse, reason: 'nothing has seen it end');
    gone = true;
    expect(await watching.ended.future.timeout(const Duration(seconds: 5)), 3);
  });

  // Harm: an output nothing could start reading leaving the program's end unsaid for ever, so Forget and Retry wait on
  // a terminal that has ended.
  test('an output nothing reads does not keep the end from being said', () async {
    final watching = watched(
      read: (to) => Future<Object?>.delayed(const Duration(milliseconds: 20), () => throw StateError('no reader')),
      wait: (to) async => to.send(3),
    );

    expect(await watching.ended.future.timeout(const Duration(seconds: 5)), 3);
  });

  // Harm: a reader whose isolate died without saying the output ended keeping the program's end unsaid for ever.
  test('a reader that died counts as drained', () async {
    final watching = watched(
      read: (to) async {
        to.send(Uint8List.fromList([0x41]));
        // What an isolate's onExit port receives once it is gone.
        to.send(null);
        return null;
      },
      wait: (to) async => to.send(3),
    );

    expect(await watching.ended.future.timeout(const Duration(seconds: 5)), 3);
  });

  // Harm: a throw while the program is asked for, or while its console is closed, raised as an error nobody handles,
  // every poll, and the end never said.
  test('a throw while asking or closing counts as still running', () async {
    var asked = 0;
    final output = StreamController<List<int>>.broadcast();
    final ended = Completer<int>();
    ConPty.watch(
      closeConsole: () => throw StateError('closing failed'),
      output: output,
      ended: ended,
      read: (to) async => to.send('drained'),
      wait: (to) async => throw StateError('no waiter'),
      endedNow: () => ++asked < 3 ? throw StateError('cannot ask') : const ProgramEnd(3, whole: true),
      poll: const Duration(milliseconds: 5),
    );

    expect(await ended.future.timeout(const Duration(seconds: 5)), 3);
  });

  // Harm: a waiter that started and then failed leaving the program's end unsaid for ever, so Forget and Retry wait on
  // a terminal whose program may have ended long ago.
  test('a waiter that fails after it started counts as running and the program is asked for here', () async {
    var gone = false;
    final watching = watched(
      read: (to) async => to.send('drained'),
      // What an isolate's onError port receives: the error and its stack, as two strings.
      wait: (to) async => to.send(<String>['Null check operator used on a null value', '']),
      endedNow: () => gone ? const ProgramEnd(3, whole: true) : null,
    );

    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(watching.ended.isCompleted, isFalse, reason: 'nothing has seen it end');
    gone = true;
    expect(await watching.ended.future.timeout(const Duration(seconds: 5)), 3);
  });
}
