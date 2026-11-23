import 'dart:convert';

/// The daemon's recording of one terminal session's output, as the stand-ins serve it: Screen's `end` and the
/// `offset` of each page are byte positions in it, and a `before` that is none of those is refused, never guessed.
///
/// It acts on what it is asked and holds the lines it was given; nothing in it is a canned reply.
class SessionRecording {
  /// A recording of [lines], oldest first.
  SessionRecording(this.lines) {
    var at = 0;
    for (final line in lines) {
      _starts.add(at);
      at += utf8.encode(line).length + 1;
    }
    end = at;
  }

  /// Every line of the session's output, oldest first.
  final List<String> lines;

  /// The byte position of the recording's end: Screen's `end`.
  late final int end;

  final List<int> _starts = <int>[];
  final Set<int> _handedOut = <int>{};

  /// The last [count] lines, as Screen gives them, and the position it hands out as `end`.
  (List<String>, int) screen(int count) {
    _handedOut.add(end);
    return (lines.sublist(lines.length > count ? lines.length - count : 0), end);
  }

  /// The [count] lines before the position [before], and where the first starts. Throws [BadPosition] for a position
  /// that was not handed out, or a count outside 1 to 1000.
  ({List<String> lines, int offset, bool atStart}) before(int before, int count) {
    if (count < 1 || count > 1000 || !_handedOut.contains(before)) throw const BadPosition();
    final last = before == end ? lines.length : _starts.indexOf(before);
    final first = last > count ? last - count : 0;
    final offset = first < _starts.length ? _starts[first] : 0;
    _handedOut.add(offset);
    return (lines: lines.sublist(first, last), offset: offset, atStart: first == 0);
  }
}

/// A position the recording never gave, or a page size it does not allow: the daemon's InvalidParameter.
class BadPosition implements Exception {
  /// Constructor.
  const BadPosition();
}
