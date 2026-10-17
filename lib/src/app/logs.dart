import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'fleet_backend.dart';

/// One log of one task, followed as it is written.
///
/// **The subscription lives here, not in the view.** Leaving a log open in another pane must not
/// stop it, and coming back must not mean having missed what it said — the same rule the session
/// record follows, for the same reason.
class LogTail {
  /// Constructor taking which log of which task this is.
  LogTail({required this.task, required this.log, this.formatted = false});

  /// Whether its lines come as the task's agent shows them, hidden ones left out.
  final bool formatted;

  /// The container the log belongs to.
  final String task;

  /// The file within that task's state directory.
  final String log;

  /// The newest lines read, in order: at most [kept] of them.
  final List<String> lines = <String>[];

  /// How many lines are kept here at most. An agent's log runs to tens of megabytes, and the
  /// interface that kept and drew all of it ran out of memory and closed (walk 9: 53 MB
  /// in 10 240 lines). The whole file stays on the machine.
  static const int kept = 5000;

  /// How many earlier lines were let go to keep [kept].
  int dropped = 0;

  /// Adds what was read, letting the oldest go past [kept].
  void add(List<String> read) {
    lines.addAll(read);
    final over = lines.length - kept;
    if (over > 0) {
      lines.removeRange(0, over);
      dropped += over;
    }
  }

  /// Whether new output is being appended as it arrives.
  ///
  /// Suspending stops the *view* moving, never the reading: the lines keep accumulating so that
  /// resuming shows what was written meanwhile rather than a gap.
  bool following = true;

  /// Why it stopped, or null while it is being read.
  ///
  /// `NoSuchLog` lands here: naming a log a task does not have is an answer, not a failure of the
  /// interface, and it is the answer somebody gets while looking for the right name.
  String? problem;

  /// Whether it is still being read.
  bool get live => problem == null;
}

/// Every log this session has opened, and what it has read.
class Logs extends ChangeNotifier {
  final Map<String, LogTail> _open = <String, LogTail>{};
  final Map<String, StreamSubscription<List<String>>> _reading =
      <String, StreamSubscription<List<String>>>{};
  bool _disposed = false;

  /// What has been opened, oldest first.
  List<LogTail> get all => List<LogTail>.unmodifiable(_open.values);

  /// One that is already open, or null.
  LogTail? find(String task, String log, {bool formatted = false}) => _open[_keyOf(task, log, formatted)];

  /// How many of a log's last lines are read when it is opened.
  static const int firstLines = 1000;

  /// Opens a log, or hands back the one already open on it.
  LogTail open(FleetBackend backend, String task, String log, {bool formatted = false}) {
    final key = _keyOf(task, log, formatted);
    final already = _open[key];
    if (already != null) return already;

    final tail = LogTail(task: task, log: log, formatted: formatted);
    _open[key] = tail;
    // Only the end of it: the earlier lines are not drawn anyway, and a log of tens of megabytes
    // need not cross the connection to show its last screen (a sliding window).
    _reading[key] = backend.tailLog(task, log, last: firstLines, formatted: formatted).listen(
      (lines) {
        tail.add(lines);
        _soon();
      },
      onError: (Object error) {
        tail.problem = _wordsFor(error, task, log);
        _stopReading(key);
        _notify();
      },
      onDone: () {
        // A log that ends is a log that has been fully read, not one that failed.
        _stopReading(key);
        _notify();
      },
    );
    _notify();
    return tail;
  }

  /// Stops the view moving with the output, without stopping the reading.
  void follow(LogTail tail, {required bool following}) {
    if (tail.following == following) return;
    tail.following = following;
    _notify();
  }

  /// Closes one and forgets what it read.
  void close(LogTail tail) {
    final key = _keyOf(tail.task, tail.log, tail.formatted);
    _stopReading(key);
    _open.remove(key);
    _notify();
  }

  static String _wordsFor(Object error, String task, String log) {
    if (error is VarlinkException && error.simpleName == 'NoSuchLog') {
      return '$task has no log called "$log".';
    }
    if (error is FeatureNotSupported) return '$error';
    if (error is VarlinkDisconnected) return 'Lost contact while reading: ${error.message}';
    return '$error';
  }

  static String _keyOf(String task, String log, [bool formatted = false]) =>
      formatted ? '$task/$log, formatted' : '$task/$log';

  void _stopReading(String key) {
    _reading.remove(key)?.cancel();
  }

  void _notify() {
    if (_disposed) return;
    _pending?.cancel();
    _pending = null;
    notifyListeners();
  }

  /// How often lines that keep arriving are drawn at most. A log written hard, line by line, would
  /// otherwise redraw the view for every line, and following it flickered (walk 9).
  static const Duration drawnAtMostEvery = Duration(milliseconds: 100);

  Timer? _pending;

  /// Draws what arrived with what arrives next, once [drawnAtMostEvery] has passed.
  void _soon() {
    if (_disposed || _pending != null) return;
    _pending = Timer(drawnAtMostEvery, _notify);
  }

  @override
  void dispose() {
    _disposed = true;
    _pending?.cancel();
    for (final subscription in _reading.values) {
      subscription.cancel();
    }
    _reading.clear();
    super.dispose();
  }
}
