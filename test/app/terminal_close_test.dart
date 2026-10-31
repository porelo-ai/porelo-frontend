import 'dart:async';
import 'dart:io';
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

    final closing = ConPty.letGoAndWait(() => letGo = true, ended.future).then((_) => closed = true);
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
      () {},
      ended.future,
      bound: const Duration(milliseconds: 10),
    ).then<Object?>((_) => null, onError: (Object error) => error);

    expect(outlived, isA<TerminalStillRunning>());
    ended.complete(70);
    expect(await (outlived! as TerminalStillRunning).ended, 70);
  });

  // Harm: a console whose letting go blocks the interface counted against no bound, so its close waits a whole bound
  // more after the block before the program is said still running, or for ever where the block never ends.
  test('the bound runs from before the console is let go', () async {
    const bound = Duration(milliseconds: 300);
    final ended = Completer<int>();

    final outcome = ConPty.letGoAndWait(
      () => sleep(bound * 2),
      ended.future,
      bound: bound,
    ).then<Object?>((_) => null, onError: (Object error) => error);

    expect(
      await outcome.timeout(bound ~/ 2, onTimeout: () => 'still waiting'),
      isA<TerminalStillRunning>(),
      reason: 'the bound passed while the console was let go',
    );
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
}
