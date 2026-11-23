import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/src/app/desk.dart';

import '../client/models.dart';
import 'fleet_backend.dart';
import 'start_refusals.dart' show startRefusalWords;
import 'window_log.dart';
import '../wire/limit_factors.dart' show machineSettings;

/// Where a long operation got to.
enum OperationState {
  /// Still going.
  running,

  /// Finished, and did what it said.
  succeeded,

  /// Finished, and did not. The output says why.
  failed,
}

/// One long operation the interface started, and everything it produced.
///
/// Builds, synchronisations and setup run for minutes and print a great deal. The output is kept
/// here rather than on screen, so that leaving the view does not lose it and arriving late does
/// not mean having missed it.
class Operation {
  /// Constructor taking what it is and when it began.
  Operation({required this.id, required this.title, required this.startedAt, this.machine = ''});

  /// Identifies it for the life of the session.
  final String id;

  /// What it is, in words, for somebody reading the list an hour later.
  final String title;

  /// When it began.
  final DateTime startedAt;

  /// The machine it ran on, by name.
  final String machine;

  /// When it stopped, or null while it is still going.
  DateTime? finishedAt;

  /// Where it got to.
  OperationState state = OperationState.running;

  /// What became of it, in the same words whether it worked or not.
  String summary = 'Running.';

  /// Everything it printed, in order.
  final List<String> output = <String>[];

  /// Each start step's latest state, in the order the steps first arrived.
  final Map<String, StartStep> steps = <String, StartStep>{};

  /// Whether it is still going.
  bool get running => state == OperationState.running;

  /// Whether it finished badly. Reported in the same place success would have been.
  bool get failed => state == OperationState.failed;

  /// Whether a person has had it open since it failed. A failure nobody has seen waits under Needs
  /// you; one that was open while it failed was watched failing.
  bool seen = false;

  /// Whether it was run before this window was opened, and read back from the file.
  bool fromBefore = false;

  /// Where the rest of what it printed is read from, or null when everything it printed is in [output].
  OutputSource? source;

  /// How many lines of [output] came from before the lines the person was looking at when the record was
  /// opened: [output] from here on is the part that grows downward. See the view.
  int anchor = 0;

  /// What the last read of [source] said when it failed, or null.
  String? readProblem;

  /// How many of [output]'s lines were appended to the record file already.
  int linesAppended = 0;

  /// How many lines it printed, as the record said when it was read back, or null where the record does not say.
  int? linesPrintedBefore;

  /// How many lines it printed.
  int? get linesPrinted => fromBefore ? linesPrintedBefore : output.length;

  /// How many lines could not be written to the record file.
  int linesLost = 0;

  /// Whether its record file was looked for since this window opened it, and what that found is what is held.
  bool opened = false;

  /// Whether the record file is being opened now.
  bool opening = false;

  /// How many of the lines the record says were kept are not in the file it reads, where that is known.
  int linesShort = 0;

  /// How many lines the record says were printed and kept, and are not in the file.
  int get linesGone {
    if (!fromBefore || !opened || readProblem != null) return 0;
    if (source != null) return linesShort;
    final kept = (linesPrinted ?? 0) - linesLost;
    return kept > 0 ? kept : 0;
  }

  /// Whether lines the record says were kept are not in the file.
  bool get linesMissing => linesGone > 0;

  /// Looks for the record file, set where a record is read back; null when the file is not there.
  /// It throws where the file is there and cannot be opened.
  Future<OutputSource?> Function()? recordOf;

  /// Opens the record at its end, as often as it is shown: where the reader was last time is not where a new
  /// opening starts. What the file holds is not read before this is asked for.
  Future<void> openAtEnd() async {
    final find = recordOf;
    if (find == null || opening) return;
    opening = true;
    readProblem = null;
    try {
      final found = await find();
      if (found == null) {
        source = null;
        output.clear();
        _ends.clear();
        anchor = 0;
        linesShort = 0;
      } else {
        await openRecord(found);
      }
    } on Exception catch (error) {
      source = null;
      output.clear();
      _ends.clear();
      anchor = 0;
      readProblem = '$error';
    } finally {
      opening = false;
      opened = true;
    }
  }

  /// Where in the record the first and the one-past-last line of [output] lie, and how far the record reaches.
  int _from = 0;
  int _to = 0;
  int _recordEnd = 0;
  final List<int> _ends = <int>[];
  bool _reading = false;

  /// How many lines one read of the record brings.
  static const int pageLines = 400;

  /// How many lines of a record are held at most; reading past that lets go of the far end.
  static const int windowLines = 1600;

  /// Whether the record holds lines before the first one held.
  bool get hasOlder => source != null && _from > 0;

  /// Whether the record holds lines after the last one held.
  bool get hasNewer => source != null && _to < _recordEnd;

  /// Whether [id] is one the window made, and so one that can name a file without naming another.
  static bool validId(String id) => RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id);

  /// Opens [from] at its end: holds the last page of it.
  Future<void> openRecord(OutputSource from) async {
    final end = await from.size();
    final page = await from.before(end, pageLines);
    source = from;
    _recordEnd = end;
    _to = end;
    _from = page.start;
    output
      ..clear()
      ..addAll(page.lines);
    _ends
      ..clear()
      ..addAll(page.ends);
    anchor = 0;
    // A file that is whole in this one page and holds fewer lines than were kept lost some of them.
    final expected = (linesPrintedBefore ?? 0) - linesLost;
    linesShort = fromBefore && page.start == 0 && expected > output.length ? expected - output.length : 0;
    opened = true;
  }

  /// Lets go of lines at the far end, so that one more page fits in the window, and says whether that moved
  /// where the lines are counted from: then whoever shows them must keep the reader's place.
  ///
  /// Lines on the far side of [anchor] go without moving anything on screen. Only when those are not enough does
  /// [anchor] move: to the line at [keep], one the reader sees, so that it can be put where it was exactly, or to
  /// the first line where there is none.
  bool makeRoom({required bool forOlder, int? keep}) {
    final over = output.length + pageLines - windowLines;
    if (source == null || over <= 0) return false;
    final held = output.length;
    final dropped = over < held ? over : held;
    if (forOlder) {
      final forward = held - anchor;
      output.removeRange(held - dropped, held);
      _ends.removeRange(held - dropped, held);
      _to = _ends.isEmpty ? _from : _ends.last;
      if (dropped <= forward) return false;
      anchor = keep != null && keep < output.length ? keep : 0;
      return true;
    } else {
      _from = _ends[dropped - 1];
      output.removeRange(0, dropped);
      _ends.removeRange(0, dropped);
      if (dropped <= anchor) {
        anchor -= dropped;
        return false;
      }
      final kept = keep == null ? -1 : keep - dropped;
      anchor = kept >= 0 && kept < output.length ? kept : 0;
      return true;
    }
  }

  /// Reads the page before the first line held, and says whether lines were added.
  ///
  /// [settle] is told whether making room moved the anchor, before anything is read. A failed read is kept
  /// in [readProblem], never shown as the start of the record.
  Future<bool> loadOlder({int? keep, Future<void> Function(bool moved)? settle}) async {
    final from = source;
    if (from == null || _reading || _from == 0) return false;
    _reading = true;
    try {
      final moved = makeRoom(forOlder: true, keep: keep);
      if (settle != null) await settle(moved);
      final page = await from.before(_from, pageLines);
      readProblem = null;
      output.insertAll(0, page.lines);
      _ends.insertAll(0, page.ends);
      anchor += page.lines.length;
      _from = page.start;
      return true;
    } on Exception catch (error) {
      readProblem = '$error';
      return false;
    } finally {
      _reading = false;
    }
  }

  /// Reads the page after the last line held, and says whether lines were added.
  Future<bool> loadNewer({int? keep, Future<void> Function(bool moved)? settle}) async {
    final from = source;
    if (from == null || _reading || _to >= _recordEnd) return false;
    _reading = true;
    try {
      final moved = makeRoom(forOlder: false, keep: keep);
      if (settle != null) await settle(moved);
      final page = await from.after(_to, pageLines);
      readProblem = null;
      output.addAll(page.lines);
      _ends.addAll(page.ends);
      _to = page.ends.isEmpty ? _recordEnd : page.ends.last;
      return true;
    } on Exception catch (error) {
      readProblem = '$error';
      return false;
    } finally {
      _reading = false;
    }
  }

  /// A copy that shows what this shows now, for a row that must not change under a reader.
  Operation copy() {
    final other = Operation(id: id, title: title, startedAt: startedAt, machine: machine)
      ..finishedAt = finishedAt
      ..state = state
      ..summary = summary
      ..seen = seen
      ..fromBefore = fromBefore
      ..source = source
      ..anchor = anchor
      ..linesAppended = linesAppended
      ..linesPrintedBefore = linesPrintedBefore
      ..linesLost = linesLost
      ..recordOf = recordOf
      ..opened = opened
      ..linesShort = linesShort
      ..readProblem = readProblem
      .._from = _from
      .._to = _to
      .._recordEnd = _recordEnd;
    other.output.addAll(output);
    other._ends.addAll(_ends);
    other.steps.addAll(steps);
    return other;
  }

  /// What the file holds of it. The lines it printed are not in this: they go to a file of their own, one
  /// line at a time, so that none is ever dropped.
  Map<String, Object?> toStored() => <String, Object?>{
    'id': id,
    'title': title,
    'machine': machine,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'finishedAt': finishedAt?.toUtc().toIso8601String(),
    'state': state.name,
    'summary': summary,
    'seen': seen,
    'lines': linesPrinted,
    'linesLost': linesLost,
    'steps': <Object?>[for (final step in steps.values) step.toStored()],
  };

  /// One read back from the file, or null for a record that does not say what it needs to.
  static Operation? fromStored(Object? stored) {
    if (stored is! Map) return null;
    final id = stored['id'];
    final title = stored['title'];
    final started = DateTime.tryParse('${stored['startedAt']}');
    final state = OperationState.values.where((each) => each.name == stored['state']).firstOrNull;
    if (id is! String || !validId(id) || title is! String || started == null || state == null) return null;
    final machine = stored['machine'];
    final summary = stored['summary'];
    final steps = stored['steps'];
    return Operation(id: id, title: title, startedAt: started.toLocal(), machine: machine is String ? machine : '')
      ..state = state
      ..finishedAt = DateTime.tryParse('${stored['finishedAt']}')?.toLocal()
      ..summary = summary is String ? summary : ''
      ..seen = stored['seen'] == true
      ..fromBefore = true
      ..linesPrintedBefore = stored['lines'] is int ? stored['lines'] as int : null
      ..linesLost = stored['linesLost'] is int ? stored['linesLost'] as int : 0
      ..steps.addEntries(<MapEntry<String, StartStep>>[
        if (steps is List)
          for (final step in steps.whereType<Map<String, dynamic>>().map(StartStep.from)) MapEntry(step.step, step),
      ]);
  }
}

/// A page of a run's record: [lines], where the first begins, and where each ends.
class OutputPage {
  /// Constructor taking the lines and their places.
  const OutputPage(this.lines, this.ends, this.start);

  /// The lines, in order.
  final List<String> lines;

  /// Where each line ends in the record, one for each of [lines].
  final List<int> ends;

  /// Where the first line begins, which is where the page ends when it was read backward.
  final int start;
}

/// What a run printed, kept whole and read in pages from either end.
abstract interface class OutputSource {
  /// How far the record reaches now.
  Future<int> size();

  /// Up to [count] lines that end at or before [position], the last of them last.
  Future<OutputPage> before(int position, int count);

  /// Up to [count] lines that begin at or after [position].
  Future<OutputPage> after(int position, int count);
}

/// A record file with one JSON string per line, read in chunks so that the whole of it is never held.
class FileOutput implements OutputSource {
  /// Constructor taking the file.
  FileOutput(this.file);

  /// The record.
  final File file;

  static const int _chunk = 64 * 1024;
  static const int _newline = 0x0A;

  @override
  Future<int> size() => file.length();

  @override
  Future<OutputPage> before(int position, int count) async {
    if (position <= 0 || count <= 0) return OutputPage(const <String>[], const <int>[], 0);
    final handle = await file.open();
    try {
      var from = position;
      var newlines = 0;
      final parts = <Uint8List>[];
      // One line more than asked for, unless the start is reached: the first is cut where the chunk began.
      while (from > 0 && newlines <= count) {
        final step = from < _chunk ? from : _chunk;
        from -= step;
        await handle.setPosition(from);
        final read = await handle.read(step);
        newlines += read.where((byte) => byte == _newline).length;
        parts.insert(0, read);
      }
      final joined = BytesBuilder(copy: false);
      parts.forEach(joined.add);
      final bytes = joined.takeBytes();
      var begin = 0;
      if (from > 0) begin = bytes.indexOf(_newline) + 1;
      final starts = <int>[];
      final ends = <int>[];
      for (var at = begin; at < bytes.length; at++) {
        if (bytes[at] != _newline) continue;
        starts.add(begin);
        ends.add(at);
        begin = at + 1;
      }
      final keep = starts.length > count ? starts.length - count : 0;
      return OutputPage(
        <String>[for (var i = keep; i < starts.length; i++) _line(bytes, starts[i], ends[i])],
        <int>[for (var i = keep; i < starts.length; i++) from + ends[i] + 1],
        starts.isEmpty ? 0 : from + starts[keep],
      );
    } finally {
      await handle.close();
    }
  }

  @override
  Future<OutputPage> after(int position, int count) async {
    final handle = await file.open();
    try {
      await handle.setPosition(position);
      var newlines = 0;
      final parts = <Uint8List>[];
      while (newlines < count) {
        final read = await handle.read(_chunk);
        if (read.isEmpty) break;
        newlines += read.where((byte) => byte == _newline).length;
        parts.add(read);
      }
      final joined = BytesBuilder(copy: false);
      parts.forEach(joined.add);
      final bytes = joined.takeBytes();
      final lines = <String>[];
      final ends = <int>[];
      var begin = 0;
      for (var at = 0; at < bytes.length && lines.length < count; at++) {
        if (bytes[at] != _newline) continue;
        lines.add(_line(bytes, begin, at));
        ends.add(position + at + 1);
        begin = at + 1;
      }
      return OutputPage(lines, ends, position);
    } finally {
      await handle.close();
    }
  }

  static String _line(Uint8List bytes, int begin, int end) {
    final text = utf8.decode(Uint8List.sublistView(bytes, begin, end), allowMalformed: true);
    try {
      final decoded = jsonDecode(text);
      return decoded is String ? decoded : text;
    } on FormatException {
      return text;
    }
  }
}

/// A record held in memory, with a line's place being its number.
class MemoryOutput implements OutputSource {
  /// Constructor taking the lines.
  MemoryOutput(this.lines);

  /// What was printed.
  final List<String> lines;

  @override
  Future<int> size() async => lines.length;

  @override
  Future<OutputPage> before(int position, int count) async {
    final first = position > count ? position - count : 0;
    return OutputPage(lines.sublist(first, position), <int>[for (var i = first; i < position; i++) i + 1], first);
  }

  @override
  Future<OutputPage> after(int position, int count) async {
    final last = position + count < lines.length ? position + count : lines.length;
    return OutputPage(lines.sublist(position, last), <int>[for (var i = position; i < last; i++) i + 1], position);
  }
}

/// Where what was run is kept between runs of the window.
abstract interface class OperationsStore {
  /// The file it is kept in, or null where it is kept nowhere a person could open.
  File? get file;

  /// Everything kept, as written; throws where it is there and cannot be read whole.
  Future<List<Object?>> read();

  /// Replaces everything kept, except what the operations printed.
  Future<void> write(List<Object?> records);

  /// Adds [lines] to the end of what operation [id] printed, and says whether they were kept.
  Future<bool> appendOutput(String id, List<String> lines);

  /// Forgets what every operation printed except those named in [keep].
  Future<void> pruneOutput(Set<String> keep);

  /// What operation [id] printed, null when no file of it is there, and a throw where it is there and cannot be opened.
  Future<OutputSource?> outputOf(String id);

  /// Forgets what operation [id] printed.
  Future<void> deleteOutput(String id);
}

/// What was run, kept in one file in the user's state directory.
class FileOperationsStore implements OperationsStore {
  /// Constructor, optionally pointed at another file for tests.
  FileOperationsStore({File? file}) : file = file ?? defaultFile();

  @override
  final File file;

  /// Where it is kept unless told otherwise, read from [environment] or this process's.
  static File defaultFile([Map<String, String>? environment, String? operatingSystem]) {
    final here = Desk.of(operatingSystem ?? Platform.operatingSystem, environment ?? Platform.environment);
    return File(here.join(<String>[here.state, 'operations.json']));
  }

  @override
  Future<List<Object?>> read() async {
    // A file that is not there is a window that has run nothing yet. One that cannot be read whole is said, so
    // that nothing is taken for gone because of it.
    if (!await file.exists()) return const <Object?>[];
    final decoded = jsonDecode(await file.readAsString());
    final records = decoded is Map ? decoded['operations'] : null;
    if (records is! List) throw const FormatException('The record of what was run does not hold a list of operations.');
    return records;
  }

  /// The folder what the operations printed is kept in, one file for each, beside the record.
  Directory get outputFolder => Directory('${file.path}.output');

  // Only ids the window makes name a file, so that two ids never name one and none leaves the folder.
  File _outputFile(String id) {
    if (!Operation.validId(id)) throw ArgumentError.value(id, 'id', 'Not an operation id');
    return File('${outputFolder.path}/$id.jsonl');
  }

  /// What was made private in this process: tried again until it worked, then not asked again.
  static final Set<String> _private = <String>{};

  /// Ids whose file is known to end with a line break.
  final Set<String> _clean = <String>{};

  Future<void> _keepPrivate(String path, {bool directory = false}) async {
    if (_private.contains(path)) return;
    await desk.keepPrivate(path, directory: directory);
    _private.add(path);
  }

  /// Every line is one JSON string, so that a line with a line break in it is still one line of the file.
  @override
  Future<bool> appendOutput(String id, List<String> lines) async {
    if (lines.isEmpty) return true;
    final target = _outputFile(id);
    try {
      if (!await outputFolder.exists()) {
        // Made again, so what was made private of it before no longer is.
        _private.removeWhere((path) => path.startsWith(outputFolder.path));
        await outputFolder.create(recursive: true);
      }
      await _keepPrivate(outputFolder.path, directory: true);
      // Made private while still empty, so no line of a run is ever readable by another account.
      if (!await target.exists()) {
        _private.remove(target.path);
        _clean.remove(id);
        await target.create();
      }
      await _keepPrivate(target.path);
      var text = '${lines.map(jsonEncode).join('\n')}\n';
      // An append that failed halfway left a line that was not ended: it must not take the next one with it.
      if (!_clean.contains(id) && !await _endsWithBreak(target)) text = '\n$text';
      _clean.remove(id);
      await target.writeAsString(text, mode: FileMode.append, flush: true);
      _clean.add(id);
      return true;
    } on Exception catch (error) {
      // Not worth interrupting the run over, but never lost unsaid.
      windowLog.warn('${lines.length} lines of operation $id could not be kept in its record: $error');
      return false;
    }
  }

  static Future<bool> _endsWithBreak(File target) async {
    final handle = await target.open();
    try {
      final length = await handle.length();
      if (length == 0) return true;
      await handle.setPosition(length - 1);
      return await handle.readByte() == 0x0A;
    } finally {
      await handle.close();
    }
  }

  @override
  Future<void> pruneOutput(Set<String> keep) async {
    try {
      if (!await outputFolder.exists()) return;
      await for (final entry in outputFolder.list()) {
        final name = entry.uri.pathSegments.last;
        if (entry is File && name.endsWith('.jsonl') && !keep.contains(name.substring(0, name.length - 6))) {
          await entry.delete();
        }
      }
    } on Exception {
      // What is left is only a file nobody reads.
    }
  }

  @override
  Future<OutputSource?> outputOf(String id) async {
    final target = _outputFile(id);
    try {
      await target.length();
      return FileOutput(target);
    } on PathNotFoundException {
      return null;
    }
  }

  @override
  Future<void> deleteOutput(String id) async {
    try {
      final target = _outputFile(id);
      if (await target.exists()) await target.delete();
    } on Exception {
      // What is left is only a file nobody reads.
    }
  }

  /// Written beside it and renamed over it, owner-only — the way the settings are, and for the
  /// same reasons: a half-written file must never read as a whole one, and what ran names hosts.
  @override
  Future<void> write(List<Object?> records) async {
    try {
      await file.parent.create(recursive: true);
      final beside = File('${file.path}.writing');
      await beside.writeAsString(jsonEncode(<String, Object?>{'operations': records}), flush: true);
      await desk.keepPrivate(beside.path);
      await beside.rename(file.path);
    } on Exception {
      // Losing the record of a run is not worth interrupting the run over.
    }
  }
}

/// What was run, kept in memory, for tests that restart the window.
class MemoryOperationsStore implements OperationsStore {
  /// Constructor, optionally naming a file for the record to point at.
  MemoryOperationsStore({this.file});

  @override
  final File? file;

  List<Object?> _records = const <Object?>[];

  final Map<String, List<String>> _output = <String, List<String>>{};

  /// How many times everything was written.
  int writes = 0;

  /// What each operation printed, by id.
  Map<String, List<String>> get printed => _output;

  @override
  Future<List<Object?>> read() async => jsonDecode(jsonEncode(_records)) as List<Object?>;

  @override
  Future<void> write(List<Object?> records) async {
    writes++;
    _records = jsonDecode(jsonEncode(records)) as List<Object?>;
  }

  @override
  Future<bool> appendOutput(String id, List<String> lines) async {
    (_output[id] ??= <String>[]).addAll(lines);
    return true;
  }

  @override
  Future<void> pruneOutput(Set<String> keep) async => _output.removeWhere((id, _) => !keep.contains(id));

  @override
  Future<OutputSource?> outputOf(String id) async => _output[id] == null ? null : MemoryOutput(_output[id]!);

  @override
  Future<void> deleteOutput(String id) async => _output.remove(id);
}

/// Why an operation failed, in the words of whatever refused, and nothing else.
///
/// An operation's summary is the error's text, and a `StateError` would put *"Bad state:"* in front
/// of a sentence somebody reads on a tile.
class FailedSaying implements Exception {
  /// Constructor taking what came back.
  const FailedSaying(this.words);

  /// What came back.
  final String words;

  @override
  String toString() => words;
}

/// Every long operation started in this session, in the order they were started.
///
/// The session record is what makes an unattended machine reviewable: somebody comes back after
/// an hour and needs to know what happened, in order, without having watched.
///
/// **The subscription lives here, not in a view.** That is the whole point of the class: closing
/// the window onto an operation must not stop it, and nothing that is watched should have to stay
/// watched.
class Operations extends ChangeNotifier {
  /// Constructor, keeping what is run in [store] when there is one.
  ///
  /// [saveDelay] gathers the lines of a busy operation into one write; the start, the end and
  /// being seen are written at once.
  Operations({
    this.store,
    DateTime Function()? now,
    Future<void> Function(String path)? open,
    this.saveDelay = const Duration(seconds: 1),
    Duration? Function()? keptFor,
  }) : _now = now ?? DateTime.now,
       _open = open ?? _withTheDesktop,
       _keptFor = keptFor ?? _keptByThePerson;

  /// Where what is run is kept between runs of the window, or null for nowhere.
  final OperationsStore? store;

  /// How long lines are gathered before they are written.
  final Duration saveDelay;

  final DateTime Function() _now;
  final Future<void> Function(String path) _open;

  final Duration? Function() _keptFor;

  /// How long anything is kept: the person's `records.kept_days`, as this computer's Porelo gave it; null while it has
  /// not, and then nothing is dropped for its age.
  Duration? get kept => _keptFor();

  static Duration? _keptByThePerson() => switch (machineSettings.of(null)?.keptDays) {
    final days? => Duration(days: days),
    null => null,
  };

  /// How many operations were older than [kept] and dropped.
  int droppedAsOld = 0;

  /// The file what is run is kept in, or null.
  File? get file => store?.file;

  Timer? _pending;
  Future<void> _writing = Future<void>.value();

  final List<Operation> _all = <Operation>[];
  final Map<String, StreamSubscription<Object>> _running = <String, StreamSubscription<Object>>{};
  int _counted = 0;
  bool _disposed = false;

  /// Everything started in this session, oldest first.
  List<Operation> get all => List<Operation>.unmodifiable(_all);

  /// How many are still going.
  int get running => _all.where((operation) => operation.running).length;

  /// The most recently started one, or null when nothing has run.
  Operation? get latest => _all.isEmpty ? null : _all.last;

  /// Marks one as seen by a person, which is what puts a failure away from Needs you.
  void see(Operation operation) {
    if (operation.seen) return;
    operation.seen = true;
    _notify();
    _saveNow();
  }

  /// Reads back what earlier runs of the window ran, dropping what is older than [kept] where that is known.
  ///
  /// **An operation that was still running is not reported as finished well**: the window that
  /// watched it closed, so how it ended is not known, and that is said as a failure nobody has seen.
  Future<void> load() async {
    final from = store;
    if (from == null) return;
    final earlier = <Operation>[];
    var changed = false;
    var whole = true;
    var stored = const <Object?>[];
    try {
      stored = await from.read();
    } on Exception catch (error) {
      // Not read whole: nothing in it is taken for gone, so no file of what was printed is removed.
      whole = false;
      windowLog.warn('What was run could not be read, so what it printed is kept as it is: $error');
    }
    // Every record that names an id keeps its file, also one that is not understood.
    final named = <String>{
      for (final record in stored)
        if (record is Map && record['id'] is String) record['id'] as String,
    };
    // An id of a record that is not understood is not handed out again either: its file is kept.
    for (final id in named) {
      final number = int.tryParse(id.replaceFirst('operation-', ''));
      if (number != null && number > _counted) _counted = number;
    }
    for (final record in stored) {
      final operation = Operation.fromStored(record);
      if (operation == null) continue;
      // What it printed is read when a person opens it, not now: the list needs only what the record says.
      final id = operation.id;
      operation.recordOf = () => from.outputOf(id);
      if (operation.running) {
        operation
          ..state = OperationState.failed
          ..summary = 'The window closed while this was running, so how it ended is not known.';
        changed = true;
      }
      final number = int.tryParse(operation.id.replaceFirst('operation-', ''));
      if (number != null && number > _counted) _counted = number;
      earlier.add(operation);
    }
    // A file that belongs to no record is what an earlier session left, and no id of a new one may meet it.
    if (whole) await from.pruneOutput(named);
    _all.insertAll(0, earlier);
    _notify();
    if (changed) _saveNow();
    await forgetOld();
  }

  /// Drops what started before [kept], with what it printed; nothing while [kept] is not known, so a record is never
  /// lost to a length nobody set. Asked again once this computer's Porelo gave the person's settings.
  Future<void> forgetOld() async {
    final keep = kept;
    final from = store;
    if (keep == null || from == null) return;
    final oldest = _now().subtract(keep);
    final old = [
      for (final operation in _all)
        if (!operation.running && operation.startedAt.isBefore(oldest)) operation,
    ];
    if (old.isEmpty) return;
    for (final operation in old) {
      // Another drop running meanwhile took it already.
      if (!_all.remove(operation)) continue;
      droppedAsOld++;
      try {
        await from.deleteOutput(operation.id);
      } on Exception catch (error) {
        // Its record goes all the same; the file left belongs to no record and goes at the next start.
        windowLog.warn('What operation ${operation.id} printed could not be deleted: $error');
      }
    }
    _notify();
    _saveNow();
  }

  /// Waits until everything so far is written.
  Future<void> flush() async {
    if (_pending != null) _saveNow();
    await _writing;
  }

  /// Opens the file what is run is kept in, with whatever this desktop opens files with.
  Future<void> openTheFile() async {
    final where = file;
    if (where == null) return;
    await _open(where.path);
  }

  static Future<void> _withTheDesktop(String path) => desk.open(path);

  void _saveSoon() {
    // A start that answers after the window went writes nothing: the record was written as it closed.
    if (store == null || _disposed) return;
    if (saveDelay == Duration.zero) return _saveNow();
    _pending ??= Timer(saveDelay, _saveNow);
  }

  void _saveNow() {
    final to = store;
    if (to == null || _disposed) return;
    _pending?.cancel();
    _pending = null;
    // Every line it printed is kept, in a file of its own that only grows; what was already written is not again.
    final printed = <String, List<String>>{
      for (final operation in _all)
        if (!operation.fromBefore && operation.output.length > operation.linesAppended)
          operation.id: operation.output.sublist(operation.linesAppended),
    };
    for (final operation in _all) {
      if (!operation.fromBefore) operation.linesAppended = operation.output.length;
    }
    // One after another: two writes racing over the same file beside it would rename half of one.
    _writing = _writing.then((_) async {
      for (final entry in printed.entries) {
        // A gap is said in the record, never left silent.
        if (!await to.appendOutput(entry.key, entry.value)) byId(entry.key)?.linesLost += entry.value.length;
      }
      await to.write(<Object?>[for (final operation in _all) operation.toStored()]);
    });
  }

  /// One by [id], or null when this session never had it.
  Operation? byId(String id) {
    for (final operation in _all) {
      if (operation.id == id) return operation;
    }
    return null;
  }

  /// Starts one, recording strings or [StartEvent]s from [output] until it ends.
  ///
  /// The stream completing is success and the stream erroring is failure — which is how a
  /// non-zero exit reaches here, because the thing that knows what an exit code means is the
  /// caller and not this.
  Operation run({required String title, required Stream<Object> output, String machine = ''}) {
    final operation = Operation(
      id: 'operation-${++_counted}',
      title: title,
      startedAt: DateTime.now(),
      machine: machine,
    );
    _all.add(operation);
    windowLog.info('Started: $title.', machine: machine);
    // A file left under this id, by a record that could not be read, is not this operation's.
    final to = store;
    if (to != null) _writing = _writing.then((_) => to.deleteOutput(operation.id));

    _running[operation.id] = output.listen(
      (event) {
        switch (event) {
          case StartStep():
            operation.steps[event.step] = event;
          case StartLine(:final line) || String() && final line:
            operation.output.add(line);
          default:
            throw ArgumentError.value(event, 'output', 'Expected a line or start step');
        }
        _notify();
        _saveSoon();
      },
      onError: (Object error) => _finish(
        operation,
        OperationState.failed,
        // Failure is reported as failure and in words, never as a silent stop nor as the wire's type name.
        error is OperationFailed && error.exitCode == 69 && operation.steps.isNotEmpty
            ? ''
            : startRefusalWords(error, machine: machine.isEmpty ? 'the machine' : machine),
      ),
      onDone: () {
        // onError already settled it; a stream may do both.
        if (operation.running) {
          _finish(operation, OperationState.succeeded, 'Finished.');
        }
      },
    );

    _notify();
    _saveNow();
    return operation;
  }

  void _finish(Operation operation, OperationState state, String summary) {
    operation.state = state;
    operation.summary = summary;
    operation.finishedAt = DateTime.now();
    if (state == OperationState.failed) {
      windowLog.warn('Failed: ${operation.title}${summary.isEmpty ? '' : ': $summary'}', machine: operation.machine);
    } else {
      windowLog.info('Finished: ${operation.title}.', machine: operation.machine);
    }
    _running.remove(operation.id)?.cancel();
    _notify();
    _saveNow();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_pending != null) _saveNow();
    _disposed = true;
    for (final subscription in _running.values) {
      subscription.cancel();
    }
    _running.clear();
    super.dispose();
  }
}
