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

  /// The window: the lines held here, in order, oldest first. At most [kept] of them.
  final List<String> lines = <String>[];

  /// How many lines are held here at most. An agent's log runs to tens of megabytes, and the
  /// interface that kept and drew all of it ran out of memory and closed (walk 9: 53 MB
  /// in 10 240 lines). The whole file stays on the machine, and what lies outside the window is
  /// read again from it when the view comes back.
  static const int kept = 5000;

  /// How far apart, in lines, the positions of a page are noted when lines arrive in small bunches:
  /// where the window may be cut at its start and still say where the earlier lines end.
  static const int _noteEvery = 100;

  /// How many of the first [lines] were read from before the first reply, by asking for earlier
  /// ones. The view draws them above where it opened, so what arrives of them never moves what a
  /// person is reading.
  int earlier = 0;

  /// How many lines have arrived at the end of the log since it was opened. Only ever grows.
  int arrived = 0;

  /// The byte position in the log where `lines.first` starts, the `before` of the next call for
  /// earlier lines; null where the daemon did not say, which an older one does not.
  int? start;

  /// Whether nothing lies before the first line held: the log's start, as the daemon said it.
  bool atStart = false;

  /// Whether the machine refused the position of the first line held, so that earlier lines can only be
  /// had by reading the log again from its end.
  bool refusedPosition = false;

  /// How many pages in a row came back with no line, hidden by the formatting; after [Logs.emptyPagesInARow]
  /// of them nothing more is asked until a person scrolls again.
  int emptyPages = 0;

  /// Whether asking is held until a person scrolls again, after [emptyPages] empty pages.
  bool waitForScroll = false;

  /// How many earlier lines were let go with no position to read them again from.
  int dropped = 0;

  /// Whether the lines at the end of the window were let go to make room for earlier ones. What
  /// arrives after is no longer taken in, since it would leave a gap; the view offers to read the
  /// log again from its end.
  bool newerDropped = false;

  /// Where earlier lines stand: being read, refused, or not served by this machine.
  OlderLines older = OlderLines.idle;

  /// What went wrong asking for earlier lines, in words, while [older] is [OlderLines.failed].
  String? olderWords;

  /// Said above the log after it was read again, and why.
  String? notice;

  /// Counts the times the log was read again from its end, so an answer to an earlier read is let go.
  int generation = 0;

  // Where each noted line stands in the log: the window may start at any of these.
  final List<({int index, int offset})> _notes = <({int index, int offset})>[];

  /// Adds what was read at the end of the log.
  void add(LogChunk chunk) {
    if (newerDropped) return;
    final offset = chunk.offset;
    // Reading back means not being moved by what arrives: past the window, the newest are not taken in,
    // since cutting the oldest end would move what is being read, and a part of them would leave a gap.
    if (!following && lines.isNotEmpty && lines.length + chunk.lines.length > kept) {
      newerDropped = true;
      return;
    }
    if (lines.isEmpty) {
      start = offset;
      atStart = offset == 0;
      _notes.clear();
    }
    if (_notes.isEmpty || lines.length - _notes.last.index >= _noteEvery) {
      _notes.add((index: lines.length, offset: offset));
    }
    lines.addAll(chunk.lines);
    arrived += chunk.lines.length;
    _letTheStartGo();
  }

  // Past [kept], the oldest lines go, cut where a position is noted so that they can be read again.
  void _letTheStartGo() {
    final over = lines.length - kept;
    if (over <= 0) return;
    final cut = _notes.indexWhere((note) => note.index >= over);
    if (cut < 0) {
      lines.removeRange(0, over);
      dropped += over;
      earlier = earlier > over ? earlier - over : 0;
      _notes.clear();
      start = null;
      atStart = false;
      return;
    }
    final note = _notes[cut];
    lines.removeRange(0, note.index);
    earlier = earlier > note.index ? earlier - note.index : 0;
    final left = <({int index, int offset})>[
      for (final each in _notes.skip(cut)) (index: each.index - note.index, offset: each.offset),
    ];
    _notes
      ..clear()
      ..addAll(left);
    start = note.offset;
    atStart = false;
  }

  /// Puts a page of earlier lines before the first one held, and lets the newest go past [kept].
  void prepend(LogPage page) {
    lines.insertAll(0, page.lines);
    earlier += page.lines.length;
    final moved = <({int index, int offset})>[
      (index: 0, offset: page.offset),
      for (final each in _notes) (index: each.index + page.lines.length, offset: each.offset),
    ];
    _notes
      ..clear()
      ..addAll(moved);
    start = page.offset;
    atStart = page.atStart;
    final over = lines.length - kept;
    if (over > 0) {
      lines.removeRange(lines.length - over, lines.length);
      _notes.removeWhere((note) => note.index >= lines.length);
      if (earlier > lines.length) earlier = lines.length;
      newerDropped = true;
      following = false;
    }
  }

  /// Forgets what was read, to read the log again from its end.
  void reset() {
    lines.clear();
    _notes.clear();
    earlier = 0;
    arrived = 0;
    start = null;
    atStart = false;
    dropped = 0;
    newerDropped = false;
    older = OlderLines.idle;
    olderWords = null;
    refusedPosition = false;
    emptyPages = 0;
    waitForScroll = false;
    problem = null;
    following = true;
    generation++;
  }

  /// Whether a request for earlier lines may be made now.
  bool get wantsOlder => start != null && !atStart && older == OlderLines.idle && problem == null && !waitForScroll;

  /// Whether the view is taken to new output as it arrives.
  ///
  /// Suspending keeps what is being read from moving: lines that arrive meanwhile are held while the
  /// window has room, and past it they are not taken in at all ([newerDropped]), since cutting the window's
  /// oldest end would move the reader. Following again reads the log from its end then.
  bool following = true;

  /// Why it stopped, or null while it is being read.
  ///
  /// `NoSuchLog` lands here: naming a log a task does not have is an answer, not a failure of the
  /// interface, and it is the answer somebody gets while looking for the right name.
  String? problem;

  /// Whether it is still being read.
  bool get live => problem == null;
}

/// Where a log's earlier lines stand.
enum OlderLines {
  /// Nothing is being asked for.
  idle,

  /// A page is being read.
  loading,

  /// The last request was refused or lost; a person asks again.
  failed,
}

/// Every log this session has opened, and what it has read.
class Logs extends ChangeNotifier {
  final Map<String, LogTail> _open = <String, LogTail>{};
  final Map<String, StreamSubscription<LogChunk>> _reading = <String, StreamSubscription<LogChunk>>{};
  final Map<String, FleetBackend> _backends = <String, FleetBackend>{};
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
    _backends[key] = backend;
    _read(key, backend, tail);
    _notify();
    return tail;
  }

  // Reads from the log's end: only the end of it, since the earlier lines are not drawn anyway and a log of
  // tens of megabytes need not cross the connection to show its last screen. What lies before is asked for
  // when the view reaches its top.
  //
  // With [replacing], what the window holds stays until the first chunk arrives: a log that cannot be read
  // from its end leaves what was read where it is, and [notServed] says why.
  void _read(
    String key,
    FleetBackend backend,
    LogTail tail, {
    bool replacing = false,
    String? notice,
    String Function(Object error)? notServed,
  }) {
    var first = replacing;
    void failedToReplace(Object? error) {
      _stopReading(key);
      tail.older = OlderLines.failed;
      tail.olderWords = notServed!(error ?? 'nothing was sent');
      _notify();
    }

    _reading[key] = backend
        .tailLog(tail.task, tail.log, last: firstLines, formatted: tail.formatted)
        .listen(
          (chunk) {
            if (first) {
              first = false;
              tail.reset();
              tail.notice = notice;
            }
            tail.add(chunk);
            if (tail.newerDropped) {
              _stopReading(key);
              _notify();
              return;
            }
            _soon();
          },
          onError: (Object error) {
            if (first) return failedToReplace(error);
            tail.problem = _wordsFor(error, tail.task, tail.log);
            _stopReading(key);
            _notify();
          },
          onDone: () {
            if (first) return failedToReplace(null);
            // A log that ends is a log that has been fully read, not one that failed.
            _stopReading(key);
            _notify();
          },
        );
  }

  /// How many earlier lines one request asks for, the most the daemon gives.
  static const int olderPage = 1000;

  /// Reads the page of lines that lie before the first one held and puts it in front of them.
  ///
  /// Nothing is asked while a page is on its way, once the log's start is reached, where the machine
  /// does not serve it, or after a refusal until [tail] is asked again with [retryOlder].
  Future<void> readOlder(LogTail tail, {bool again = false}) async {
    final key = _keyOf(tail.task, tail.log, tail.formatted);
    final backend = _backends[key];
    final before = tail.start;
    if (_disposed || _open[key] != tail || backend == null || before == null || !tail.wantsOlder) return;
    final generation = tail.generation;
    tail.older = OlderLines.loading;
    _notify();
    LogPage page;
    try {
      page = await backend.logBefore(tail.task, tail.log, before: before, lines: olderPage, formatted: tail.formatted);
    } on Object catch (error) {
      if (_stale(key, tail, generation)) return;
      if (error is VarlinkException && error.simpleName == 'NoSuchLog') {
        // The machine no longer has the log that was read. What was read stays; the log is read from its end
        // only if the machine still serves one of that name, and replaces it once something arrives.
        _readAgain(
          key,
          backend,
          tail,
          notice: 'The machine no longer had this log as it was read. It is read again from its end.',
          notServed: (error) => error is VarlinkException && error.simpleName == 'NoSuchLog'
              ? 'This log no longer exists on the machine. What was read stays here.'
              : 'The log could not be read again from its end: ${_wordsFor(error, tail.task, tail.log)}',
        );
        return;
      } else if (error is VarlinkException && error.simpleName == 'InvalidParameter') {
        // Said as the machine's refusal of a position this window held; it is not guessed to be anything else.
        tail.refusedPosition = true;
        tail.older = OlderLines.failed;
        tail.olderWords =
            'The machine refused the position of the earlier lines. Trying again reads the log from its end.';
      } else {
        tail.older = OlderLines.failed;
        tail.olderWords = 'Earlier lines could not be read: ${_wordsFor(error, tail.task, tail.log)}';
      }
      _notify();
      return;
    }
    if (_stale(key, tail, generation)) return;
    // Lines that arrived meanwhile cut the window's oldest end: the page ends where the window began, not
    // where it begins now, so putting it in front would leave a gap. It is let go and asked for again.
    if (tail.start != before) {
      tail.older = OlderLines.idle;
      _notify();
      if (!again) return readOlder(tail, again: true);
      // Moved again while the second page was read: said, not asked for for ever.
      tail.older = OlderLines.failed;
      tail.olderWords = 'The log moved on while earlier lines were read. Trying again asks for them once more.';
      _notify();
      return;
    }
    if (!page.atStart && page.offset >= before) {
      // Never taken for the start: a page that does not move would be asked for again for ever.
      tail.older = OlderLines.failed;
      tail.olderWords = 'Earlier lines could not be read: the machine answered a page that does not reach back.';
      _notify();
      return;
    }
    tail.prepend(page);
    tail.older = OlderLines.idle;
    // The window made room by letting its newest lines go: what arrives is not taken in any more.
    if (tail.newerDropped) _stopReading(key);
    _notify();
    // A page the formatting emptied still moved back: the next is asked for, since nothing on screen
    // changed that would ask again.
    if (page.lines.isEmpty) {
      tail.emptyPages++;
      if (tail.emptyPages >= emptyPagesInARow) {
        // Nothing shown for a long way back: not asked for again until a person scrolls.
        tail.waitForScroll = true;
        _notify();
        return;
      }
      if (!page.atStart && !tail.newerDropped) return readOlder(tail);
    } else {
      tail.emptyPages = 0;
    }
  }

  /// How many pages in a row may come back empty before a person has to scroll again.
  static const int emptyPagesInARow = 3;

  /// A person scrolled to the top again: asking is not held any more.
  void scrolledToTheTop(LogTail tail) {
    tail.waitForScroll = false;
    tail.emptyPages = 0;
  }

  /// Asks again for earlier lines after a refusal.
  Future<void> retryOlder(LogTail tail) async {
    if (tail.refusedPosition) {
      readNewest(tail);
      return;
    }
    if (tail.older == OlderLines.failed) tail.older = OlderLines.idle;
    return readOlder(tail);
  }

  /// Reads the log again from its end, forgetting what the window held.
  void readNewest(LogTail tail) {
    final key = _keyOf(tail.task, tail.log, tail.formatted);
    final backend = _backends[key];
    if (_disposed || _open[key] != tail || backend == null) return;
    _readAgain(
      key,
      backend,
      tail,
      notServed: (error) => 'The log could not be read from its end: ${_wordsFor(error, tail.task, tail.log)}',
    );
  }

  // Reads from the end again, and replaces what the window holds once a first reply arrives, never before.
  void _readAgain(
    String key,
    FleetBackend backend,
    LogTail tail, {
    String? notice,
    required String Function(Object error) notServed,
  }) {
    _stopReading(key);
    tail.older = OlderLines.loading;
    _read(key, backend, tail, replacing: true, notice: notice, notServed: notServed);
    _notify();
  }

  bool _stale(String key, LogTail tail, int generation) =>
      _disposed || _open[key] != tail || tail.generation != generation;

  /// Switches following: off keeps what is read from moving while the reading goes on, on takes the view to the
  /// newest, which is read from the log's end where the window let its newest lines go.
  void follow(LogTail tail, {required bool following}) {
    // The newest lines were let go and the reading stopped: following them means reading from the end.
    if (following && tail.newerDropped) {
      readNewest(tail);
      return;
    }
    if (tail.following == following) return;
    tail.following = following;
    _notify();
  }

  /// Closes one and forgets what it read.
  void close(LogTail tail) {
    final key = _keyOf(tail.task, tail.log, tail.formatted);
    _stopReading(key);
    _open.remove(key);
    _backends.remove(key);
    _notify();
  }

  static String _wordsFor(Object error, String task, String log) {
    if (error is VarlinkException && error.simpleName == 'NoSuchLog') {
      return '$task has no log called "$log".';
    }
    if (error is FeatureNotSupported) return '$error';
    if (error is FormatException) return 'The machine answered something this window cannot read: ${error.message}';
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
    _backends.clear();
    super.dispose();
  }
}
