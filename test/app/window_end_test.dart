import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/window_end.dart';

/// The window's end on SIGTERM and SIGINT, which take the signals' default end away: tested on the function they call,
/// with streams in place of the real signals.
void main() {
  late StreamController<ProcessSignal> term;
  late StreamController<ProcessSignal> interrupt;
  late List<String> said;

  setUp(() {
    term = StreamController<ProcessSignal>();
    interrupt = StreamController<ProcessSignal>();
    said = [];
  });

  tearDown(() async {
    await term.close();
    await interrupt.close();
  });

  void watch(Future<void> Function() end) =>
      endOnSignals([term.stream, interrupt.stream], end: end, exit: (code) => said.add('exit $code'));

  // Harm: a window ended by a signal leaves the planner it started running, or never ends at all.
  for (final (name, signal) in [('SIGTERM', ProcessSignal.sigterm), ('SIGINT', ProcessSignal.sigint)]) {
    test('$name ends what the window started first, then the window with 0', () async {
      final ending = Completer<void>();
      watch(() async {
        said.add('end');
        await ending.future;
        said.add('ended');
      });

      (signal == ProcessSignal.sigterm ? term : interrupt).add(signal);
      await pumpEventQueue();
      expect(said, ['end'], reason: 'the window waits for the end before it exits');
      ending.complete();
      await pumpEventQueue();

      expect(said, ['end', 'ended', 'exit 0']);
    });
  }

  // Harm: a failed end keeps the window from ending, since the signal's own end is taken away.
  test('the window ends with 0 also where ending what it started failed', () async {
    watch(() async => throw StateError('the planner could not be ended'));

    term.add(ProcessSignal.sigterm);
    await pumpEventQueue();

    expect(said, ['exit 0']);
  });

  // Harm: a second signal while the window ends ends the planner twice or exits before the first end finished.
  test('a second signal while the window ends changes nothing', () async {
    final ending = Completer<void>();
    var ends = 0;
    watch(() async {
      ends++;
      await ending.future;
    });

    term.add(ProcessSignal.sigterm);
    interrupt.add(ProcessSignal.sigint);
    await pumpEventQueue();
    expect(said, isEmpty);
    ending.complete();
    await pumpEventQueue();

    expect(ends, 1);
    expect(said, ['exit 0']);
  });
}
