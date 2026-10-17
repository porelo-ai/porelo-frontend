import 'package:flutter/foundation.dart';

/// What one line of a diff is.
enum DiffLineKind {
  /// Unchanged, shown for context.
  context,

  /// Added by the work.
  added,

  /// Removed by it.
  removed,

  /// A `@@ ... @@` header saying where the next lines sit.
  hunk,
}

/// One line of a diff.
@immutable
class DiffLine {
  /// Constructor taking what the line is and what it says.
  const DiffLine(this.kind, this.text);

  /// What kind of line it is.
  final DiffLineKind kind;

  /// The line without its leading marker.
  final String text;
}

/// One file a piece of work changed.
@immutable
class ChangedFile {
  /// Constructor taking the path and what happened to it.
  const ChangedFile({required this.path, required this.lines, this.wasAt, this.added = false, this.removed = false});

  /// Where the file is now — or was, when it was removed.
  final String path;

  /// Where it used to be, when it moved. Null otherwise.
  final String? wasAt;

  /// Whether the work created it.
  final bool added;

  /// Whether the work deleted it.
  final bool removed;

  /// Its diff, hunk headers included.
  final List<DiffLine> lines;

  /// How many lines it gained.
  int get insertions => lines.where((line) => line.kind == DiffLineKind.added).length;

  /// How many it lost.
  int get deletions => lines.where((line) => line.kind == DiffLineKind.removed).length;

  /// What happened to it, in one word, for a row that has no room for more.
  String get what => added
      ? 'added'
      : removed
      ? 'removed'
      : wasAt != null
      ? 'moved'
      : 'changed';
}

/// Reads a unified diff into the files it touches.
///
/// The gate answers `Review` with a diff as one string, which is the whole of what can be known
/// about a change from here: there is no method that reads a file at a revision, so what is
/// *around* a hunk cannot be shown. A file tree built from the hunks is the honest ceiling, and
/// taking the diff somewhere else is the way past it.
///
/// Tolerant on purpose. This is git's output, not a promise in the IDL, and a review that refused
/// to render because a header was unfamiliar would be worse than one that shows the lines it
/// understood.
List<ChangedFile> parseUnifiedDiff(String diff) {
  final files = <ChangedFile>[];
  var path = '';
  String? wasAt;
  var added = false;
  var removed = false;
  var lines = <DiffLine>[];

  void finish() {
    if (path.isEmpty && lines.isEmpty) return;
    files.add(ChangedFile(path: path, wasAt: wasAt, added: added, removed: removed, lines: lines));
    path = '';
    wasAt = null;
    added = false;
    removed = false;
    lines = <DiffLine>[];
  }

  for (final line in _linesOf(diff)) {
    if (line.startsWith('diff --git ')) {
      finish();
      path = _pathFrom(line);
      continue;
    }
    if (line.startsWith('--- ')) {
      final from = _withoutPrefix(line.substring(4));
      if (from == null) {
        added = true;
      } else if (path.isNotEmpty && from != path) {
        wasAt = from;
      }
      continue;
    }
    if (line.startsWith('+++ ')) {
      final to = _withoutPrefix(line.substring(4));
      if (to == null) {
        removed = true;
      } else if (path.isEmpty) {
        path = to;
      }
      continue;
    }
    if (line.startsWith('@@')) {
      lines.add(DiffLine(DiffLineKind.hunk, line));
      continue;
    }
    // Only inside a hunk: git's headers — index, mode, similarity — are noise in a review, and
    // one this build has never seen must not end up rendered as a changed line.
    if (lines.isEmpty) continue;
    if (line.startsWith('+')) {
      lines.add(DiffLine(DiffLineKind.added, line.substring(1)));
    } else if (line.startsWith('-')) {
      lines.add(DiffLine(DiffLineKind.removed, line.substring(1)));
    } else if (line.startsWith(' ')) {
      lines.add(DiffLine(DiffLineKind.context, line.substring(1)));
    } else if (line.startsWith(r'\')) {
      // "\ No newline at end of file" — worth keeping, and it is not a change.
      lines.add(DiffLine(DiffLineKind.context, line));
    }
  }
  finish();
  return files;
}

/// The path a `diff --git a/x b/x` line names, taking the second half.
String _pathFrom(String header) {
  final parts = header.substring('diff --git '.length).split(' ');
  if (parts.length < 2) return '';
  return _withoutPrefix(parts.last) ?? '';
}

/// Strips git's `a/` or `b/`, and answers null for `/dev/null`.
String? _withoutPrefix(String path) {
  final name = path.split('\t').first.trim();
  if (name == '/dev/null') return null;
  if (name.startsWith('a/') || name.startsWith('b/')) return name.substring(2);
  return name;
}

/// The lines of [text], whatever line ending it used, with no trailing empty one.
List<String> _linesOf(String text) {
  final lines = text.split(RegExp(r'\r\n|\n|\r'));
  if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
  return lines;
}
