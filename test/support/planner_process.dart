import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A planner the window started, driven by the test: it ends on a signal only where it heeds that signal, and never
/// on its own clock.
class PlannerProcess extends Fake implements Process {
  /// A planner that ends on SIGTERM unless [ignoresTerm], and always on SIGKILL.
  /// What it writes is [stdout] and [stderr], nothing where none is given.
  PlannerProcess({this.ignoresTerm = false, Stream<List<int>>? stdout, Stream<List<int>>? stderr})
    : stdout = stdout ?? const Stream.empty(),
      stderr = stderr ?? const Stream.empty() {
    _input.stream.listen((_) {});
    _stdin = IOSink(_input.sink);
  }

  /// Whether it goes on running after SIGTERM, as a planner stuck in its stop does.
  final bool ignoresTerm;

  /// Every signal sent to it, in order, also after it ended.
  final signals = <ProcessSignal>[];

  final _input = StreamController<List<int>>();
  final _exit = Completer<int>();
  late final IOSink _stdin;

  /// Whether it has ended.
  bool get ended => _exit.isCompleted;

  /// Ends it with [code], as a planner ends by itself.
  void endWith(int code) {
    if (!_exit.isCompleted) _exit.complete(code);
  }

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    // Recorded also once it ended, where the system may have given its number to another process meanwhile.
    signals.add(signal);
    if (ended) return false;
    if (signal == ProcessSignal.sigkill || (signal == ProcessSignal.sigterm && !ignoresTerm)) {
      endWith(-signal.signalNumber);
    }
    return true;
  }

  @override
  IOSink get stdin => _stdin;
  @override
  final Stream<List<int>> stdout;
  @override
  final Stream<List<int>> stderr;
  @override
  Future<int> get exitCode => _exit.future;
}
