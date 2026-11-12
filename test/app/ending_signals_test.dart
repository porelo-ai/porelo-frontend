import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/ending_signals.dart';

/// A window ended by a signal takes its forwards down with it.
void main() {
  // Harm: a kill or `q` leaving every forward this interface raised running after the window is gone.
  test('a watched signal lets go of the forwards, then exits', () async {
    final signal = StreamController<ProcessSignal>();
    addTearDown(signal.close);
    final happened = <String>[];
    final exited = Completer<int>();
    letGoOnSignals(
      [signal.stream],
      letGo: [
        () async {
          happened.add('let go');
          await Future<void>.delayed(const Duration(milliseconds: 20));
          happened.add('let go done');
        },
      ],
      exit: (code) {
        happened.add('exit');
        exited.complete(code);
      },
    );

    signal.add(ProcessSignal.sigterm);

    expect(await exited.future.timeout(const Duration(seconds: 2)), 128 + ProcessSignal.sigterm.signalNumber);
    expect(happened, <String>['let go', 'let go done', 'exit']);
  });

  // Harm: a window that never ends because letting go hangs.
  test('a signal exits within its bound also when letting go hangs', () async {
    final signal = StreamController<ProcessSignal>();
    addTearDown(signal.close);
    final exited = Completer<int>();
    letGoOnSignals(
      [signal.stream],
      letGo: [() => Completer<void>().future],
      exit: exited.complete,
      within: const Duration(milliseconds: 100),
    );

    signal.add(ProcessSignal.sigint);

    expect(await exited.future.timeout(const Duration(seconds: 2)), 128 + ProcessSignal.sigint.signalNumber);
  });

  // Harm: the login forwards left running because letting go of the tunnels hung or threw.
  test('one clean-up that hangs or throws stops none of the others', () async {
    final signal = StreamController<ProcessSignal>();
    addTearDown(signal.close);
    final done = <String>[];
    final exited = Completer<int>();
    letGoOnSignals(
      [signal.stream],
      letGo: [
        () => Completer<void>().future,
        () async => throw StateError('the tunnels would not go'),
        () async => done.add('forwards'),
      ],
      exit: exited.complete,
      within: const Duration(milliseconds: 200),
    );

    signal.add(ProcessSignal.sigterm);
    await exited.future.timeout(const Duration(seconds: 2));

    expect(done, <String>['forwards']);
  });
}
