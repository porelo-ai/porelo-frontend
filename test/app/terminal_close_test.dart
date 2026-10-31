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

  ({ConsoleRelease release, List<String> calls}) released({required bool? jobEnds}) {
    final calls = <String>[];
    final release = ConsoleRelease(
      endJob: jobEnds == null
          ? null
          : () {
              calls.add('end job');
              return jobEnds;
            },
      closeJob: () => calls.add('close job'),
      closeConsole: () => calls.add('close console here'),
      closeConsoleAway: () async => calls.add('close console away'),
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

  // Harm: the waiter asking twice for an end it was told once, and dying on the second answer, so the end is never said.
  test('the waiter takes the end it was told, asking once per turn', () {
    final answers = <int?>[null, 3, null];
    var asked = 0;

    final code = ConPty.waitUntilEnded(() => answers[asked++], () {});

    expect([code, asked], [3, 2]);
  });

  ({StreamController<List<int>> output, Completer<int> ended}) watched({
    required Future<Object?> Function(SendPort to) read,
    required Future<Object?> Function(SendPort to) wait,
    int? Function()? endedNow,
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
      endedNow: () => gone ? 3 : null,
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

  // Harm: a waiter that started and then failed leaving the program's end unsaid for ever, so Forget and Retry wait on
  // a terminal whose program may have ended long ago.
  test('a waiter that fails after it started counts as running and the program is asked for here', () async {
    var gone = false;
    final watching = watched(
      read: (to) async => to.send('drained'),
      // What an isolate's onError port receives: the error and its stack, as two strings.
      wait: (to) async => to.send(<String>['Null check operator used on a null value', '']),
      endedNow: () => gone ? 3 : null,
    );

    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(watching.ended.isCompleted, isFalse, reason: 'nothing has seen it end');
    gone = true;
    expect(await watching.ended.future.timeout(const Duration(seconds: 5)), 3);
  });
}
