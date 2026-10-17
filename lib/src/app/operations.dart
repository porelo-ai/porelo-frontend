import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/src/app/desk.dart';

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

  /// Whether it is still going.
  bool get running => state == OperationState.running;

  /// Whether it finished badly. Reported in the same place success would have been.
  bool get failed => state == OperationState.failed;

  /// Whether a person has had it open since it failed. A failure nobody has seen waits under Needs
  /// you; one that was open while it failed was watched failing.
  bool seen = false;

  /// Whether it was run before this window was opened, and read back from the file.
  bool fromBefore = false;

  /// How many of its first lines were not kept, because the file keeps only the last ones.
  int linesNotKept = 0;

  /// What the file holds of it: everything, with only the last [lines] lines of what it printed.
  Map<String, Object?> toStored(int lines) {
    final cut = output.length > lines ? output.length - lines : 0;
    return <String, Object?>{
      'id': id,
      'title': title,
      'machine': machine,
      'startedAt': startedAt.toUtc().toIso8601String(),
      'finishedAt': finishedAt?.toUtc().toIso8601String(),
      'state': state.name,
      'summary': summary,
      'seen': seen,
      'output': output.sublist(cut),
      'linesNotKept': linesNotKept + cut,
    };
  }

  /// One read back from the file, or null for a record that does not say what it needs to.
  static Operation? fromStored(Object? stored) {
    if (stored is! Map) return null;
    final id = stored['id'];
    final title = stored['title'];
    final started = DateTime.tryParse('${stored['startedAt']}');
    final state = OperationState.values.where((each) => each.name == stored['state']).firstOrNull;
    if (id is! String || title is! String || started == null || state == null) return null;
    final machine = stored['machine'];
    final summary = stored['summary'];
    final output = stored['output'];
    final notKept = stored['linesNotKept'];
    return Operation(id: id, title: title, startedAt: started.toLocal(), machine: machine is String ? machine : '')
      ..state = state
      ..finishedAt = DateTime.tryParse('${stored['finishedAt']}')?.toLocal()
      ..summary = summary is String ? summary : ''
      ..seen = stored['seen'] == true
      ..fromBefore = true
      ..linesNotKept = notKept is int ? notKept : 0
      ..output.addAll(<String>[
        if (output is List)
          for (final line in output) '$line',
      ]);
  }
}

/// Where what was run is kept between runs of the window.
abstract interface class OperationsStore {
  /// The file it is kept in, or null where it is kept nowhere a person could open.
  File? get file;

  /// Everything kept, as written.
  Future<List<Object?>> read();

  /// Replaces everything kept.
  Future<void> write(List<Object?> records);
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
    // A missing or unreadable file is a window that has run nothing yet, not a reason not to open.
    try {
      if (!await file.exists()) return const <Object?>[];
      final decoded = jsonDecode(await file.readAsString());
      final records = decoded is Map ? decoded['operations'] : null;
      return records is List ? records : const <Object?>[];
    } on Exception {
      return const <Object?>[];
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

  /// How many times everything was written.
  int writes = 0;

  @override
  Future<List<Object?>> read() async => jsonDecode(jsonEncode(_records)) as List<Object?>;

  @override
  Future<void> write(List<Object?> records) async {
    writes++;
    _records = jsonDecode(jsonEncode(records)) as List<Object?>;
  }
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
  }) : _now = now ?? DateTime.now,
       _open = open ?? _withTheDesktop;

  /// Where what is run is kept between runs of the window, or null for nowhere.
  final OperationsStore? store;

  /// How long lines are gathered before they are written.
  final Duration saveDelay;

  final DateTime Function() _now;
  final Future<void> Function(String path) _open;

  /// How long anything is kept.
  static const Duration kept = Duration(days: 30);

  /// How many of an operation's last lines are kept.
  static const int linesKept = 2000;

  /// How many operations were older than [kept] and dropped when the record was read.
  int droppedAsOld = 0;

  /// The file what is run is kept in, or null.
  File? get file => store?.file;

  Timer? _pending;
  Future<void> _writing = Future<void>.value();

  final List<Operation> _all = <Operation>[];
  final Map<String, StreamSubscription<String>> _running = <String, StreamSubscription<String>>{};
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

  /// Reads back what earlier runs of the window ran, dropping what is older than [kept].
  ///
  /// **An operation that was still running is not reported as finished well**: the window that
  /// watched it closed, so how it ended is not known, and that is said as a failure nobody has seen.
  Future<void> load() async {
    final from = store;
    if (from == null) return;
    final oldest = _now().subtract(kept);
    final earlier = <Operation>[];
    var changed = false;
    for (final record in await from.read()) {
      final operation = Operation.fromStored(record);
      if (operation == null) continue;
      if (operation.startedAt.isBefore(oldest)) {
        droppedAsOld++;
        changed = true;
        continue;
      }
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
    _all.insertAll(0, earlier);
    _notify();
    if (changed) _saveNow();
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
    if (store == null) return;
    if (saveDelay == Duration.zero) return _saveNow();
    _pending ??= Timer(saveDelay, _saveNow);
  }

  void _saveNow() {
    final to = store;
    if (to == null) return;
    _pending?.cancel();
    _pending = null;
    final records = <Object?>[for (final operation in _all) operation.toStored(linesKept)];
    // One after another: two writes racing over the same file beside it would rename half of one.
    _writing = _writing.then((_) => to.write(records));
  }

  /// One by [id], or null when this session never had it.
  Operation? byId(String id) {
    for (final operation in _all) {
      if (operation.id == id) return operation;
    }
    return null;
  }

  /// Starts one, recording what [output] prints until it ends.
  ///
  /// The stream completing is success and the stream erroring is failure — which is how a
  /// non-zero exit reaches here, because the thing that knows what an exit code means is the
  /// caller and not this.
  Operation run({required String title, required Stream<String> output, String machine = ''}) {
    final operation = Operation(
      id: 'operation-${++_counted}',
      title: title,
      startedAt: DateTime.now(),
      machine: machine,
    );
    _all.add(operation);

    _running[operation.id] = output.listen(
      (line) {
        operation.output.add(line);
        _notify();
        _saveSoon();
      },
      onError: (Object error) => _finish(
        operation,
        OperationState.failed,
        // Failure is reported as failure and in words, never as a silent stop.
        '$error',
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
