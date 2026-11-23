import 'package:flutter/foundation.dart';

import '../wire/varlink_exception.dart';
import 'fleet_backend.dart';
import 'quiet_after_dispose.dart';

/// Why there is no more earlier output to show, or what stopped it. Never the session's start unless it is [start].
enum EarlierEnd {
  /// More is to be asked for.
  more,

  /// The daemon said nothing older is kept (the recording's start, or output older than it is kept).
  start,

  /// The daemon keeps no recording of this session, so its earlier output is not kept.
  notKept,

  /// The daemon refused, or could not be asked; [EarlierOutput.problem] says what it answered.
  failed,

  /// [EarlierOutput.mostLines] are held and more would grow without bound.
  full,
}

/// A terminal session's output from before the lines its window holds, fetched from the daemon's recording in pages.
///
/// **Read only and apart from the terminal.** The live terminal's buffer is never written to: these lines are kept
/// here, newest page nearest the live terminal, and shown in a pane above it. **Bounded**: pages are at most
/// [pageLines] lines and at most [mostLines] are held; at that point it says so ([EarlierEnd.full]), never that the
/// session starts there.
class EarlierOutput extends ChangeNotifier with QuietAfterDispose {
  /// Reads [task]'s earlier output from the machine behind [backend].
  EarlierOutput({required this.backend, required this.task, required this.heldLines});

  /// The machine's daemon: the leaf's own, never the window's current one.
  final FleetBackend backend;

  /// The task whose terminal session this is.
  final String task;

  /// How many lines the window's terminal holds of the session, its buffer's line count: the most that `Screen` is
  /// asked for. Asking for more would drop lines that a history the window does not hold also has.
  final int heldLines;

  /// The most lines asked for in one page, which is the most the contract allows.
  static const int pageLines = 1000;

  /// The most lines held at once.
  static const int mostLines = 50000;

  List<String> _lines = const <String>[];
  int? _before;
  String? _of;
  List<String> _screen = const <String>[];
  bool _matching = false;
  bool _mayOverlap = false;
  int _matched = 0;
  bool _asked = false;
  bool _busy = false;
  bool _disposed = false;
  EarlierEnd _end = EarlierEnd.more;
  String? _problem;

  /// What is held, oldest first.
  List<String> get lines => _lines;

  /// Whether a request is out.
  bool get loading => _busy;

  /// Why nothing more comes, or [EarlierEnd.more].
  EarlierEnd get end => _end;

  /// What the daemon answered where [end] is [EarlierEnd.failed].
  String? get problem => _problem;

  /// Whether the newest page could not be matched with the terminal's lines, so its newest lines may be shown there
  /// too: nothing was dropped on a guess, and the pane says so beside the terminal.
  bool get mayOverlap => _mayOverlap;

  /// How many of the terminal's first lines matched the end of the newest page, and were dropped from it.
  int get matched => _matched;

  /// Whether anything was asked for yet.
  bool get asked => _asked;

  /// Asks for the next page, the first time for where the live terminal's lines end. Does nothing while a request is
  /// out or once nothing more comes; a failure is asked again only by [retry].
  Future<void> more() async {
    if (_busy || _disposed || _end != EarlierEnd.more) return;
    _asked = true;
    _busy = true;
    notifyListeners();
    try {
      await _fetch();
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Asks again after a failure.
  Future<void> retry() {
    if (_end == EarlierEnd.failed) {
      _end = EarlierEnd.more;
      _problem = null;
    }
    return more();
  }

  Future<void> _fetch({bool restarted = false}) async {
    try {
      if (_before == null) {
        // The terminal's lines end where the recording ends: they are matched against its newest lines, backward.
        final screen = await backend.screen(task, last: heldLines);
        if (_disposed) return;
        if (screen.endMalformed) {
          _end = EarlierEnd.failed;
          _problem = 'The machine sent a position for the recording that is no whole number.';
          return;
        }
        if (_of != null) {
          _lines = const <String>[];
          _matched = 0;
          _mayOverlap = false;
          _screen = const <String>[];
          _matching = false;
        }
        _of = screen.of;
        final end = screen.end;
        if (end == null) {
          _end = EarlierEnd.notKept;
          return;
        }
        _screen = screen.lines;
        _matching = true;
        _before = end;
      }
      // Pages wholly equal to the screen's lines are dropped, so go on until one shows something or none is left.
      var kept = 0;
      while (kept == 0 && _end == EarlierEnd.more) {
        if (_lines.length >= mostLines) {
          _end = EarlierEnd.full;
          break;
        }
        final page = await backend.screenBefore(task, of: _of!, before: _before!, lines: pageLines);
        if (_disposed) return;
        _before = page.offset;
        var lines = page.lines;
        if (_matching) lines = _afterTheMatch(lines);
        kept = lines.length;
        if (kept > 0) _lines = <String>[...lines.map(cutLine), ..._lines];
        if (page.atStart) {
          _end = EarlierEnd.start;
        } else if (_lines.length >= mostLines) {
          _end = EarlierEnd.full;
        } else if (page.lines.isEmpty) {
          // A page with nothing that is not the start would repeat for ever.
          _end = EarlierEnd.failed;
          _problem = 'The machine sent an empty page of earlier output that is not the start.';
        }
      }
    } on VarlinkException catch (refusal) {
      if (_disposed) return;
      if (refusal.simpleName == 'NoSuchLog') {
        _before = null;
        if (!restarted) return _fetch(restarted: true);
      }
      _end = EarlierEnd.failed;
      _problem =
          'The machine refused: ${refusal.simpleName}${refusal.parameters.isEmpty ? '' : ' ${refusal.parameters}'}.';
    } on Object catch (error) {
      if (_disposed) return;
      _end = EarlierEnd.failed;
      _problem = 'The machine could not be asked: $error';
    }
  }

  /// What of [page], the next older one, lies before the lines that match the terminal's, matching from the newest
  /// line backward, trailing blanks ignored. Every line equal to its counterpart is dropped; the first that differs,
  /// or the terminal's oldest line passed, ends the match, and the lines older than it are kept whole.
  List<String> _afterTheMatch(List<String> page) {
    var at = page.length;
    while (at > 0 && _matched < _screen.length) {
      final theirs = _screen[_screen.length - 1 - _matched].trimRight();
      if (page[at - 1].trimRight() != theirs) break;
      _matched++;
      at--;
    }
    if (at > 0 || _matched == _screen.length) {
      _matching = false;
      // Fewer matched than the terminal shows: what was dropped is dropped all the same, and it says it is not sure.
      _mayOverlap = _matched < _screen.length;
    }
    return page.sublist(0, at);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The most characters of one recorded line kept; the rest is said to be left out.
const mostLineCharacters = 4000;

/// [line] cut where it is longer than [mostLineCharacters], so a line held costs a bounded amount of memory.
String cutLine(String line) => line.length <= mostLineCharacters
    ? line
    : '${line.substring(0, mostLineCharacters)} … (${line.length - mostLineCharacters} more characters not shown)';
