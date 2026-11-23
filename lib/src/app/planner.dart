import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:porelo_planning/porelo_planning.dart'
    show
        HttpPlanningSource,
        PlannerAddress,
        PlannerProject,
        PlannerProjects,
        PlanningClient,
        PlanningLanding,
        PlanningProvider,
        PlanningRefusal,
        PlanningTaskEnded,
        PlanningTaskEvent,
        TaskEventResolution;

import '../client/models.dart' show Project, defaultProject;
import 'machines.dart';
import 'owned_process.dart';
import 'planner_build.dart';
import 'planner_log_level.dart';
import 'porelo_executable.dart';
import 'report_at_planner.dart';
import 'window_log.dart' show LogLevel, windowLog;

/// Where the package puts the planner, which the window starts as it needs it.
const plannerInstalled = '/usr/libexec/porelo/planner';

/// The planner's name on the path, as a build of its own is called.
const plannerOnThePath = 'porelo-planner';

/// What the planning place says where this computer has no planner to start.
const plannerNotInstalled =
    'Planning comes from porelo-planner, which is not installed on this computer. '
    'Install the porelo-planner package and open Porelo again.';

/// What the planning place says on Windows where this computer has no planner to start.
const plannerNotInstalledOnWindows =
    'Planning comes from porelo-planner, which is not installed on this computer. '
    'Install porelo-planner for Windows and open Porelo again.';

/// What the planning place says on Windows where the planner is installed but does not run, beside its start.
const plannerNotRunningOnWindows = 'porelo-planner does not run on this computer. Start it to plan here.';

/// What the planning place says while the window looks for the planner or waits for the one it started.
const plannerLookedFor = 'Looking for porelo-planner…';

/// Reports a change of a task the window started, through the offer it keeps for it.
typedef PlanningReport = Future<void> Function(
  String project,
  String task,
  PlanningTaskEvent event, {
  required String offer,
  required String container,
  required String machine,
  PlanningTaskEnded? ended,
  List<PlanningLanding> landed,
});

/// Starts the planner at [executable] with [environment] added to the window's own, which never passes on a Porelo
/// path it inherited, answering the process started.
typedef StartPlanner = Future<Process> Function(String executable, Map<String, String> environment);

/// The most of one line of a started planner's output the window holds before it logs it, in characters, so output
/// that never ends a line is not held without limit.
const plannerOutputLine = 64 * 1024;

/// The planner's option that has it end once its standard input closes, as when the window that holds it ends.
const plannerEndsWithInput = '--end-with-input';

/// How long a planner the window started has to end by itself once its input is closed on Windows, which has no
/// SIGTERM, or once it was sent SIGTERM elsewhere; with the two seconds a hard end then has, the whole end stays within
/// the five seconds the window gives its ends on a signal.
const plannerInputEndWait = Duration(seconds: 3);

/// Opens the planner's board reads from the address file under [runtimeDirectory], the account's own when null.
typedef OpenPlanner = Future<HttpPlanningSource> Function(PlannerProjects projects, {String? runtimeDirectory});

/// The planner this account runs, as [HttpPlanningSource.fromAddressFile] calls it, telling each task report it sends
/// of what came of it, so a report sent through the planning screen's run is known taken or not.
class WindowPlannerSource extends HttpPlanningSource implements TellsTaskReports {
  /// Calls the planner at [base] under [token], as [HttpPlanningSource] does.
  WindowPlannerSource(super.base, super.token, super.projects, {super.label, super.address});

  /// Calls the planner whose address file is under [runtimeDirectory], read again before each proof.
  static Future<HttpPlanningSource> fromAddressFile(PlannerProjects projects, {String? runtimeDirectory}) async {
    final first = await PlannerAddress.read(runtimeDirectory: runtimeDirectory);
    return WindowPlannerSource(
      first.base,
      first.token,
      projects,
      address: () => PlannerAddress.read(runtimeDirectory: runtimeDirectory),
    );
  }

  @override
  Future<TaskEventResolution> taskEvent(
    String project,
    String task,
    PlanningTaskEvent event, {
    required String offer,
    required String container,
    required String machine,
    PlanningTaskEnded? ended,
    List<PlanningLanding> landed = const [],
  }) => ReportAtPlanner.told(
    offer,
    () => super.taskEvent(
      project,
      task,
      event,
      offer: offer,
      container: container,
      machine: machine,
      ended: ended,
      landed: landed,
    ),
  );
}

/// What the window started for planning and ends with itself.
abstract interface class EndsWithTheWindow {
  /// Ends the planner the window started, where it still answers at the address it wrote; a planner the window found
  /// serving, or one that took the started one's place, is left running.
  Future<void> end();
}

/// A planner that names the file it writes its log into.
abstract interface class NamesItsLog {
  /// The log file the planner names, or null where it names none yet.
  String? get log;
}

/// The log file [address], the text of the planner's `planner.json`, names: null where it names none, or names it
/// as anything but an absolute path.
String? plannerLogOf(String address) {
  try {
    if (jsonDecode(address) case {'log': final String log}
        when log.trim().isNotEmpty && p.isAbsolute(log) && !_control.hasMatch(log)) {
      return log;
    }
  } on FormatException {
    // Not the planner's address: it names no log.
  }
  return null;
}

final _control = RegExp(r'[\x00-\x1f]');

/// A planner told the level the person chose for the logs: what its log is at, and why it did not take the level.
abstract interface class TakesTheLogLevel {
  /// The level the planner's log is at, as it answered the window's last level; null until it answered.
  LogLevel? get plannerLevel;

  /// Why the planner did not take the window's level, in words, or null where it did.
  String? get levelProblem;
}

/// A planning client that may not have reached its planning yet, and says why.
abstract interface class PlanningReach implements Listenable {
  /// What the planning place says instead of a board, or null once planning is reached.
  String? get notReached;

  /// Tries again to reach planning, as when the person refreshes.
  Future<void> reach();
}

/// A planner the window may have started itself, where none was serving.
abstract interface class StartedItsPlanner {
  /// The program the window started, while the planner that answers is the one it started; null for a planner it found
  /// running, and while none answers.
  String? get startedProgram;
}

/// A planner the window starts only when the person asks, as on Windows.
abstract interface class StartsWhenAsked {
  /// Whether the planning place offers to start the planner now.
  bool get startOffered;

  /// Starts the planner, as the person asked, and waits for its address.
  Future<void> startNow();
}

/// This computer's planner as the window's one provider of planning: found by its address file, started where none
/// runs, told each project's repository as the window knows it, and followed to a new address when the planner writes
/// one, as after a restart on another port.
class LocalPlanner extends ChangeNotifier
    implements
        PlanningClient,
        PlanningReach,
        StartsWhenAsked,
        NamesItsLog,
        TakesTheLogLevel,
        EndsWithTheWindow,
        NamesItsBuild,
        StartedItsPlanner {
  /// Takes the projects the window knows and their repositories; [runtimeDirectory] is the one the planner writes its
  /// address under, `XDG_RUNTIME_DIR` when null and none on Windows, and [candidates] where the planner may be, in the
  /// order they are tried.
  /// [onWindows] is whether the window runs on Windows, where the planner is `porelo-planner.exe` on the path and its
  /// address lies in its own folder, so no runtime directory is passed.
  LocalPlanner({
    required this._projects,
    required this._repositories,
    String? Function()? chosenProject,
    this._changes,
    String? runtimeDirectory,
    List<String>? candidates,
    StartPlanner? start,
    OpenPlanner? open,
    this.wait = const Duration(seconds: 20),
    this.poll = const Duration(milliseconds: 200),
    this.follow = const Duration(seconds: 2),
    this.probeWait = const Duration(seconds: 2),
    this.inputEndWait = plannerInputEndWait,
    bool? onWindows,
    Map<String, String>? environment,
    this._logLevel,
    TellPlannerLevel? tellLevel,
    this._poreloExecutable,
    AskPlannerBuild? askBuild,
  }) : _onWindows = onWindows ?? Platform.isWindows,
       _environment = environment ?? Platform.environment,
       _tellLevel = tellLevel ?? tellPlannerLevel,
       _askBuild = askBuild ?? askPlannerBuild,
       _chosen = chosenProject,
       // On Windows the planner keeps its address in its own folder under LOCALAPPDATA, whatever a runtime directory says.
       runtimeDirectory =
           (onWindows ?? Platform.isWindows) || runtimeDirectory == null || runtimeDirectory.trim().isEmpty
           ? null
           : runtimeDirectory,
       candidates = candidates ?? plannerCandidates(Platform.environment, onWindows: onWindows ?? Platform.isWindows),
       _start = start ?? _startWithItsInput,
       _open = open ?? WindowPlannerSource.fromAddressFile {
    _changes?.addListener(notifyListeners);
    _logLevel?.addListener(_levelChosen);
  }

  /// The watched machines' projects, each told to the planner with its own repository's upstream as its clone URL.
  factory LocalPlanner.of(
    Machines machines, {
    String? runtimeDirectory,
    List<String>? candidates,
    StartPlanner? start,
    OpenPlanner? open,
    ValueListenable<LogLevel>? logLevel,
  }) => LocalPlanner(
    logLevel: logLevel,
    poreloExecutable: _poreloOnce(),
    projects: () => plannedProjects(machines),
    repositories: (project) => plannerProjectOf(machines, project),
    chosenProject: () => machines.watching(machines.current)?.selectedProject?.name,
    changes: machines,
    runtimeDirectory: runtimeDirectory,
    candidates: candidates,
    start: start,
    open: open,
  );

  /// The provider's name, shown beside its answers.
  static const name = 'porelo-planner';

  /// Finds Porelo's executable for the planner, once, and says in the window's log why none is given where one was
  /// refused.
  static String? _poreloOnce() {
    final found = findPoreloExecutable();
    if (found.refused case final why?) {
      windowLog.warn('The planner is not given Porelo, so it reads public repositories only: $why.');
    }
    return found.path;
  }

  /// Porelo's executable, absolute with its links followed, given to a planner the window starts; null where the
  /// window found none it can vouch for.
  final String? _poreloExecutable;

  /// The runtime directory the planner writes its address under, `XDG_RUNTIME_DIR` when null; a blank one is none, and
  /// on Windows there is none: the planner writes it under `LOCALAPPDATA`.
  final String? runtimeDirectory;

  /// Where the planner may be, in the order they are tried.
  final List<String> candidates;

  /// How long the window waits for a planner it started to write its address.
  final Duration wait;

  /// How often it looks for that address meanwhile.
  final Duration poll;

  /// How often the address file of a planner found is read again, to follow the planner to a new address.
  final Duration follow;

  /// How long a connection to the port an address file names may take before the planner there is taken for alive.
  final Duration probeWait;

  /// How long a planner the window started has to end by itself, once its input is closed on Windows or once it was
  /// sent SIGTERM elsewhere, before it is ended hard.
  final Duration inputEndWait;

  final List<String> Function() _projects;
  final PlannerProjects _repositories;
  final String? Function()? _chosen;
  final Listenable? _changes;
  final StartPlanner _start;
  final OpenPlanner _open;
  final bool _onWindows;

  /// The window's environment, where the planner's address is looked for.
  final Map<String, String> _environment;
  final ValueListenable<LogLevel>? _logLevel;
  final TellPlannerLevel _tellLevel;
  final AskPlannerBuild _askBuild;
  int _levelsTold = 0;

  @override
  LogLevel? get plannerLevel => _plannerLevel;
  LogLevel? _plannerLevel;

  @override
  String? get levelProblem => _levelProblem;
  String? _levelProblem;

  Future<void>? _reaching;
  HttpPlanningSource? _source;

  /// The address file's text the source was opened from, and how the window keeps reading it.
  String? _address;
  Timer? _following;
  bool _checking = false;
  int _missing = 0;
  String? _notReached = plannerLookedFor;
  bool _disposed = false;

  /// Whether this window started a planner that has not gone since; it starts another only once one it found is gone.
  bool get started => _started;
  bool _started = false;

  @override
  String? get startedProgram => switch ((_process, _startedFirst, _address)) {
    (_?, final first?, final address?) when _source != null && _answersAt(address) == first => _startedProgram,
    _ => null,
  };

  /// The program of the planner the window started last.
  String? _startedProgram;

  /// Where the planner the window started first answered: an address read later that names another is another
  /// planner's, such as a person's own that took the address while the started one still runs.
  _Answers? _startedFirst;

  /// The planner this window started, until it ended or was ended; null where the window found one serving.
  Process? _process;

  /// Where the planner this window started answers, as its address file said first after the start.
  _Answers? _startedAt;

  /// The exit code of the planner this window started, where it ended before it said where it answers.
  int? _endedEarly;

  /// The window's end of the planner it started, once asked: every later caller waits for the same end, and no planner
  /// is started after it began.
  Future<void>? _ending;

  /// The start under way, a stop of the planner it replaces included, which an end waits for.
  Future<Object?>? _starting;

  /// Whether the window may no longer start a planner: its end began, or it was disposed.
  bool get _over => _ending != null || _disposed;

  @override
  String? get notReached => _notReached;

  /// On Windows the planner is started only on the person's ask, never by a look of the window's.
  @override
  bool get startOffered => _offered;
  bool _offered = false;
  bool _asked = false;

  @override
  Future<void> startNow() async {
    if (!_offered) return;
    _offered = false;
    _asked = true;
    // Asked again after a start that failed: one more start, the earlier planner ended first if it still runs.
    _started = false;
    _notReached = plannerLookedFor;
    notifyListeners();
    await _reaching;
    await reach();
  }

  /// The log file the planner's address file named when it was read last naming one: kept once that planner has gone,
  /// whose log tells why.
  @override
  String? get log => _log;

  String? _log;

  /// Finds the planner, starting it where none runs; asked while it looks, it answers that look's end, and asked
  /// after a failed look, it looks again, never starting a second planner.
  @override
  Future<void> reach() => _reaching ??= _reach().whenComplete(() {
    if (_source == null) _reaching = null;
  });

  Future<void> _reach() async {
    if (_disposed) return;
    if (await _look() != _Look.notRunning) return;
    if (_started) {
      _offered = true;
      return _say('porelo-planner was started, but did not say where it answers yet.');
    }
    if (runtimeDirectory case final runtime?
        when !(_onWindows ? _absoluteOnWindows(runtime) : runtime.startsWith('/'))) {
      return _say('porelo-planner cannot be started: its runtime directory $runtime is not an absolute path.');
    }
    final programs = candidates.where(_onWindows ? _aFile : _runnable).toList();
    if (programs.isEmpty) return _say(_onWindows ? plannerNotInstalledOnWindows : plannerNotInstalled);
    if (_disposed) return;
    if (_onWindows) {
      if (!_asked) {
        _offered = true;
        return _say(plannerNotRunningOnWindows);
      }
      // One ask, one start: a planner gone later is offered again.
      _asked = false;
    }
    final starting = _starting = _startOneOf(programs);
    final failure = await starting;
    if (identical(_starting, starting)) _starting = null;
    if (_over) return;
    if (failure != null) {
      // A start that failed may be asked for again, never a dead end.
      _offered = true;
      return _say('porelo-planner could not be started: $failure');
    }
    final waited = Stopwatch()..start();
    while (!_disposed) {
      await Future<void>.delayed(poll);
      if (await _look() != _Look.notRunning) return;
      if (_endedEarly case final code?) {
        _offered = true;
        return _say('porelo-planner ended with exit code $code before it said where it answers.');
      }
      if (waited.elapsed >= wait) {
        _offered = true;
        return _say('porelo-planner was started, but did not say where it answers within ${wait.inSeconds} s.');
      }
    }
  }

  /// Starts the first of [programs] that can be started, or answers why none could.
  Future<Object?> _startOneOf(List<String> programs) async {
    Object? failure;
    for (final program in programs) {
      try {
        _started = true;
        // A planner started before whose address went is ended first, so two never run side by side.
        if (_process case final before?) {
          _process = null;
          await _stop(before);
        }
        // The window's end or dispose began meanwhile: no planner may outlive it.
        if (_over) {
          _started = false;
          return null;
        }
        final process = await _start(program, {
          'XDG_RUNTIME_DIR': ?runtimeDirectory,
          poreloExecutableVariable: ?_poreloExecutable,
        });
        _startedProgram = program;
        _keep(process);
        // An end that began during the start waits for it, so the planner just started is stopped here: the end could
        // not tell it from one that took its place once it wrote its address.
        if (_ending != null) {
          _process = null;
          _started = false;
          await _stop(process);
        }
        return null;
      } on ProcessException catch (error) {
        // Not started at all, as for a file this account may not run: the next may be.
        _started = false;
        failure = error;
      } on Object catch (error) {
        return error;
      }
    }
    return failure;
  }

  /// Reads the planner's address; only a missing one means no planner runs, every other failure is said, but
  /// [quietly] where the board of the planner found still stands and says what fails.
  Future<_Look> _look({bool quietly = false}) async {
    try {
      var address = await _addressNow();
      // An address file a planner left when it ended names no planner: it is taken away, and one is started as where
      // there is none.
      if (address != null && await _removedIfStale(address)) return _Look.notRunning;
      final source = await _open(_repositories, runtimeDirectory: runtimeDirectory);
      // A planner may write its address between the two reads; the address opened is then read once more.
      address ??= await _addressNow();
      if (_disposed) {
        source.close();
        return _Look.found;
      }
      // The boards move to the new source when told, so the old one is closed only after.
      final old = _source;
      _source = source;
      _address = address;
      // While the started planner runs, it holds the address file against any other, so an address read is its own,
      // a new one included.
      if (_process != null && address != null) {
        _startedAt = _answersAt(address);
        _startedFirst ??= _startedAt;
      }
      if (address != null) _log = plannerLogOf(address) ?? _log;
      _missing = 0;
      _notReached = null;
      notifyListeners();
      old?.close();
      _following ??= Timer.periodic(follow, (_) => unawaited(_follow()));
      // A planner found, or found anew after a restart, is told the level the person chose.
      unawaited(_tellTheLevel());
      return _Look.found;
    } on PlanningRefusal catch (refusal) {
      if (refusal.name == 'NoAddress') return _Look.notRunning;
      if (!quietly) _say('porelo-planner cannot be reached: $refusal');
      return _Look.refused;
    } on Object catch (error) {
      if (!quietly) _say('porelo-planner cannot be reached: $error');
      return _Look.refused;
    }
  }

  /// The planner's address file as it reads now, or null where there is none to read.
  Future<String?> _addressNow() async {
    // On Windows the planner writes it under LOCALAPPDATA, as its package reads it there.
    final runtime = runtimeDirectory ?? _environment[_onWindows ? 'LOCALAPPDATA' : 'XDG_RUNTIME_DIR'];
    if (runtime == null || runtime.trim().isEmpty) return null;
    try {
      return await File([runtime, 'porelo-planner', 'planner.json'].join(Platform.pathSeparator)).readAsString();
    } on FileSystemException {
      return null;
    }
  }

  /// Whether [address], the address file's text, names a planner that is gone, and if so takes the file away: its
  /// process no longer runs, where the file names one and this is Linux, or nothing listens on its loopback port. The
  /// file is removed only while it still reads as [address], so a planner that wrote a new one meanwhile keeps it.
  Future<bool> _removedIfStale(String address) async {
    if (!await _gone(address)) return false;
    final runtime = runtimeDirectory ?? _environment[_onWindows ? 'LOCALAPPDATA' : 'XDG_RUNTIME_DIR'];
    if (runtime == null || runtime.trim().isEmpty) return false;
    final file = File([runtime, 'porelo-planner', 'planner.json'].join(Platform.pathSeparator));
    // Taken aside by one rename before it is read, so a new planner's file written between a read and a delete is
    // never the one deleted: a file taken aside that is not the gone planner's goes back where no newer one stands
    // yet. A planner writing in the moment between that look and the move back can still lose its file, which the
    // next follow then finds missing.
    final aside = File('${file.path}.gone-$pid');
    try {
      await file.rename(aside.path);
    } on PathNotFoundException {
      // Gone meanwhile, as when the planner took it away at its end, or taken aside by another window for a moment:
      // only a file still missing on a second look leaves room for a start.
      return await file.exists() ? false : _tookAway();
    } on FileSystemException catch (error) {
      windowLog.warn('The window could not take away the address file of a planner that is gone: $error');
      return false;
    }
    final String taken;
    try {
      taken = await aside.readAsString();
    } on Object catch (error) {
      windowLog.warn('The window could not read the planner\'s address file it took aside: $error');
      await _putBack(aside, file);
      return false;
    }
    if (taken != address) {
      await _putBack(aside, file);
      return false;
    }
    try {
      await aside.delete();
    } on FileSystemException catch (error) {
      windowLog.warn('The window could not delete the address file of a planner that is gone, set aside: $error');
    }
    return _tookAway();
  }

  /// Moves [aside], the address file of a planner that may run, back to [file], or deletes it where a newer one
  /// stands there already; says in the window's log what failed.
  Future<void> _putBack(File aside, File file) async {
    try {
      if (await file.exists()) {
        await aside.delete();
      } else {
        await aside.rename(file.path);
      }
    } on FileSystemException catch (error) {
      windowLog.warn('The window could not put the planner\'s address file back in place: $error');
    }
  }

  /// Says that a gone planner's address file was taken away, and leaves room for one more start.
  bool _tookAway() {
    windowLog.info('The planner\'s address file named a planner that is gone; the window took it away.');
    // A planner of this window's that ended leaves room for one more start.
    _started = false;
    return true;
  }

  /// Whether the planner [address] names is gone: its process id names no process, where the file gives one and this
  /// is Linux, else its loopback port refuses a connection. A port that answers, or a check that cannot be made, is
  /// not taken for gone.
  Future<bool> _gone(String address) async {
    final Object? json;
    try {
      json = jsonDecode(address);
    } on FormatException {
      return false;
    }
    if (json is! Map<String, dynamic> || json['port'] is! int) return false;
    // The process id alone decides where the file gives one on Linux, so the follow every few seconds opens no
    // connection to the planner.
    final pid = json['pid'];
    if (!_onWindows && pid is int && pid > 0) return !await Directory('/proc/$pid').exists();
    final port = json['port'] as int;
    final answer = Completer<bool>();
    // A planner that ends meanwhile resets the connection it took; the reset is then reported once more, outside the
    // call, and is caught here: the port did take the connection.
    runZonedGuarded(
      () async {
        try {
          final socket = await Socket.connect(InternetAddress.loopbackIPv4, port, timeout: probeWait);
          socket.done.ignore();
          socket.destroy();
          if (!answer.isCompleted) answer.complete(false);
        } on SocketException catch (error) {
          // Refused: nothing listens there. A wait that ran out is no proof the planner is gone.
          if (!answer.isCompleted) answer.complete(error.osError?.errorCode == (_onWindows ? 10061 : 111));
        }
      },
      (error, stack) {
        if (!answer.isCompleted) answer.complete(false);
      },
    );
    return answer.future;
  }

  /// Reads the address file of the planner found again: a new address is opened in place of the old one, and a file
  /// gone at two reads in a row means that planner is gone, so the planner is looked for, and started, as at first.
  Future<void> _follow() async {
    if (_disposed || _checking) return;
    _checking = true;
    try {
      final address = await _addressNow();
      if (_disposed) return;
      // With no planner held, as after a gone one's file was taken away and none could be started, a planner that
      // writes its address afterwards is found by the next follow.
      if (_source == null) {
        if (address != null && _reaching == null && !await _removedIfStale(address)) await reach();
        return;
      }
      if (address != null && !await _removedIfStale(address)) {
        _missing = 0;
        if (address != _address) await _look(quietly: true);
        return;
      }
      if (_disposed) return;
      // Twice, so a planner writing its file anew is not taken for none; a file of a planner gone is none at once.
      if (address == null && ++_missing < 2) return;
      final gone = _source;
      _source = null;
      _address = null;
      _missing = 0;
      _reaching = null;
      // The planner found has gone: a planner of this window's among them, so another may be started.
      _started = false;
      notifyListeners();
      gone?.close();
      await reach();
    } finally {
      _checking = false;
    }
  }

  /// Asks the planner found what it was built as; null without asking where no planner is reached, and null where the
  /// ask failed, said in the window's log.
  @override
  Future<PlannerBuild?> build() async {
    if (_source == null) return null;
    try {
      return await _askBuild(runtimeDirectory: runtimeDirectory);
    } on Object catch (error) {
      windowLog.warn('The window could not ask porelo-planner what it was built as: $error');
      return null;
    }
  }

  void _levelChosen() => unawaited(_tellTheLevel());

  /// Tells the planner found the level the person chose, and keeps what it answered; an answer overtaken by a later
  /// level is dropped.
  Future<void> _tellTheLevel() async {
    final level = _logLevel?.value;
    if (level == null || _source == null || _disposed) return;
    final told = ++_levelsTold;
    LogLevel? answered;
    String? problem;
    try {
      answered = await _tellLevel(level, runtimeDirectory: runtimeDirectory);
    } on PlannerLevelRefused catch (refusal) {
      problem = refusal.words;
    } on PlanningRefusal catch (refusal) {
      problem = refusal.toString();
    } on Exception catch (error) {
      problem = '$error';
    }
    if (_disposed || told != _levelsTold) return;
    _plannerLevel = answered;
    _levelProblem = problem;
    notifyListeners();
  }

  void _say(String words) {
    if (_disposed) return;
    _notReached = words;
    notifyListeners();
  }

  @override
  List<PlanningProvider> get providers => switch (_source) {
    final source? => [PlanningProvider(name: name, connected: true, projects: _projects(), source: source)],
    null => const [],
  };

  @override
  String? get currentProvider => _source == null ? null : name;

  @override
  String? get chosenProject => _chosen?.call();

  /// How the window reports a task it started.
  PlanningReport? reports;

  /// Reports a task the window started through the offer it keeps for it, to the provider kept with that offer, and
  /// starts what the planner answers: the window's reports, which go through the provider's source since only its
  /// answer carries the follow-up orders. Refused where the window does not report its tasks.
  @override
  Future<void> taskEvent(
    String project,
    String task,
    PlanningTaskEvent event, {
    required String offer,
    required String container,
    required String machine,
    PlanningTaskEnded? ended,
    List<PlanningLanding> landed = const [],
  }) async {
    final report = reports;
    if (report == null) {
      throw const PlanningRefusal('NotReporting', {}, 'This window does not report the tasks it starts.');
    }
    await report(
      project,
      task,
      event,
      offer: offer,
      container: container,
      machine: machine,
      ended: ended,
      landed: landed,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _following?.cancel();
    _changes?.removeListener(notifyListeners);
    _logLevel?.removeListener(_levelChosen);
    _source?.close();
    super.dispose();
  }

  /// On Windows a file is what can be run: it has no mode bits that say so.
  static bool _aFile(String path) => FileStat.statSync(path).type == FileSystemEntityType.file;

  static bool _runnable(String path) {
    final stat = FileStat.statSync(path);
    return stat.type == FileSystemEntityType.file && stat.mode & 0x49 != 0;
  }

  /// Keeps the planner the window started, and says in the window's log how it ended.
  void _keep(Process process) {
    _process = process;
    _startedAt = null;
    _startedFirst = null;
    _endedEarly = null;
    _intoTheLog(process.stdout, LogLevel.debug);
    _intoTheLog(process.stderr, LogLevel.info);
    unawaited(
      process.exitCode.then((code) {
        if (!identical(_process, process)) return;
        _process = null;
        if (_startedAt == null) _endedEarly = code;
        // The planning head no longer says the window started the planner that answers.
        if (!_disposed) notifyListeners();
        // Under its option the planner answers 0 for a clean end and 1 where its stop failed or its input could not be
        // read.
        if (code == 0) {
          windowLog.info('porelo-planner, which the window started, ended.');
        } else {
          windowLog.warn('porelo-planner, which the window started, ended with exit code $code.');
        }
      }),
    );
  }

  @override
  Future<void> end() => _ending ??= _end();

  Future<void> _end() async {
    // A start under way stops the planner it replaces first, and starts none once this end began.
    await _starting;
    final process = _process;
    if (process == null) return;
    _process = null;
    final address = await _addressNow();
    if (address != null && _answersAt(address) != _startedAt) {
      windowLog.info(
        'porelo-planner, which the window started, no longer answers at its address; the one that does is '
        'left running.',
      );
      return;
    }
    await _stop(process);
  }

  /// Stops [process], a planner the window started, and says so in the window's log: on Windows, which has no SIGTERM,
  /// through its input, elsewhere with SIGTERM and then SIGKILL.
  Future<void> _stop(Process process) async {
    windowLog.info('Ending porelo-planner, which the window started.');
    try {
      // A planner takes its address file away at its end; killed before, it leaves it behind, so it is given as long
      // as on Windows.
      await (_onWindows ? _endThroughItsInput(process) : stopOwnedProcess(process, grace: inputEndWait));
      windowLog.info('porelo-planner, which the window started, ended with exit code ${await process.exitCode}.');
    } on TimeoutException {
      windowLog.error(
        _onWindows
            ? 'porelo-planner, which the window started, did not end even when ended hard.'
            : 'porelo-planner, which the window started, did not end even on SIGKILL.',
      );
    }
  }

  /// Closes the input of [process], on whose end a planner started with [plannerEndsWithInput] ends by itself, and
  /// ends it hard only where it still runs after [inputEndWait].
  Future<void> _endThroughItsInput(Process process) async {
    // The input of a planner that already ended fails to close, which changes nothing here.
    unawaited(process.stdin.close().then<void>((_) {}, onError: (Object _) {}));
    try {
      await process.exitCode.timeout(inputEndWait);
    } on TimeoutException {
      windowLog.warn(
        'porelo-planner, which the window started, did not end within ${inputEndWait.inMilliseconds} ms of its input '
        'closing, so it is ended hard; what it was writing may be lost.',
      );
      process.kill(ProcessSignal.sigkill);
      await process.exitCode.timeout(const Duration(seconds: 2));
    }
  }

  /// Where the address file's text [address] says the planner answers: its port and token, null where it says none.
  static _Answers? _answersAt(String address) {
    try {
      if (jsonDecode(address) case {'port': final Object port, 'token': final Object token}) return (port, token);
    } on FormatException {
      // Not the planner's address: it says nowhere.
    }
    return null;
  }

  // Normal, so the planner gets a pipe for its input that closes when the window goes, a hard kill included, and
  // answers its exit code.
  static Future<Process> _startWithItsInput(String executable, Map<String, String> environment) => Process.start(
    executable,
    const [plannerEndsWithInput],
    // Its own, so a Porelo path the window inherited never reaches the planner.
    environment: plannerEnvironment(Platform.environment, environment),
    includeParentEnvironment: false,
  );

  /// Reads [output] of a planner the window started into the window's log, line by line, so the planner never blocks
  /// on a full pipe; a line longer than [plannerOutputLine] is logged in pieces of that length.
  static void _intoTheLog(Stream<List<int>> output, LogLevel level) {
    final pending = StringBuffer();
    void say() {
      var line = pending.toString();
      pending.clear();
      if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
      windowLog.write(level, 'porelo-planner: $line');
    }

    output
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(
          (text) {
            final parts = text.split('\n');
            for (var i = 0; i < parts.length; i++) {
              var part = parts[i];
              while (pending.length + part.length > plannerOutputLine) {
                final fits = plannerOutputLine - pending.length;
                pending.write(part.substring(0, fits));
                part = part.substring(fits);
                say();
              }
              pending.write(part);
              if (i < parts.length - 1) say();
            }
          },
          onError: (Object _) {},
          onDone: () {
            if (pending.isNotEmpty) say();
          },
        );
  }
}

enum _Look { found, notRunning, refused }

/// Where a planner answers: the port and token its address file names.
typedef _Answers = (Object port, Object token);

/// Where the planner may be: where its package installs it, then on [environment]'s path, taking only absolute folders
/// that climb out of none. On Windows ([onWindows]) it is `porelo-planner.exe` on the path's folders that start at a
/// drive's root, as its package and a ZIP put it there.
List<String> plannerCandidates(Map<String, String> environment, {bool onWindows = false}) => onWindows
    ? [
        for (final entry in (environment['PATH'] ?? '').split(';'))
          // An entry with spaces may stand in quotes, as Windows keeps it.
          if (entry.length > 1 && entry.startsWith('"') && entry.endsWith('"')
                  ? entry.substring(1, entry.length - 1)
                  : entry
              case final folder when _absoluteOnWindows(folder) && !folder.split(RegExp(r'[\\/]')).contains('..'))
            '${folder.endsWith(r'\') ? folder.substring(0, folder.length - 1) : folder}\\$plannerOnThePath.exe',
      ]
    : [
        plannerInstalled,
        for (final folder in (environment['PATH'] ?? '').split(':'))
          if (folder.startsWith('/') && !folder.split('/').contains('..')) '$folder/$plannerOnThePath',
      ];

/// Whether [path] is a Windows path from a drive's root, as `C:\Tools`: neither relative nor bound to a drive's own
/// current folder, as `C:Tools` is.
bool _absoluteOnWindows(String path) => RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path);

/// The projects the watched machines list, each once, without the default project, which has no repository of its own.
List<String> plannedProjects(Machines machines) => {
  for (final machine in machines.all)
    for (final project in machines.watching(machine)?.listedProjects ?? const <Project>[])
      if (project.name != defaultProject) project.name,
}.toList();

/// Where [project]'s planning is kept, as the watched machines list it, the machine shown first.
PlannerProject plannerProjectOf(Machines machines, String project) {
  final all = machines.all;
  final shown = all.isEmpty ? null : machines.current;
  return plannerProjectIn([
    for (final machine in [?shown, ...all.where((machine) => machine != shown)])
      ...?machines.watching(machine)?.listedProjects,
  ], project);
}

/// Where [project]'s planning is kept: the upstream of its own repository, the first remote clone URL of [known], else
/// the first upstream at all, which the planner then refuses in its own words; refused in words where none is named.
PlannerProject plannerProjectIn(Iterable<Project> known, String project) {
  final upstreams = [
    for (final listed in known.where((each) => each.name == project))
      listed.repositoryStates.where((each) => each.name == listed.ownRepository).firstOrNull?.upstream.trim() ?? '',
  ].where((upstream) => upstream.isNotEmpty);
  if ((upstreams.where(isRemoteCloneUrl).firstOrNull ?? upstreams.firstOrNull) case final upstream?) {
    return PlannerProject(upstream);
  }
  final words =
      'No watched machine names where $project\'s own repository is followed from, so porelo-planner cannot be told '
      'where its planning is kept.';
  // In the parameters as well, where the board reads a refusal's words.
  throw PlanningRefusal('NoRepository', {'project': project, 'detail': words}, words);
}

/// Whether [upstream] names a repository on another machine: a URL of a scheme other than `file`, or git's
/// `host:path` form, whose colon comes before any slash.
bool isRemoteCloneUrl(String upstream) {
  if (RegExp(r'^([A-Za-z][A-Za-z0-9+.-]*)://').firstMatch(upstream) case final url?) {
    return url.group(1)!.toLowerCase() != 'file';
  }
  final colon = upstream.indexOf(':');
  final slash = upstream.indexOf('/');
  return colon > 0 && (slash < 0 || colon < slash);
}
