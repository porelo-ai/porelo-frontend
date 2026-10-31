import 'dart:async';

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
}
