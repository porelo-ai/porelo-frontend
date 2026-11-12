import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:porelo_planning/porelo_planning.dart'
    show
        HttpPlanningSource,
        PlannerProject,
        PlannerProjects,
        PlanningClient,
        PlanningLanding,
        PlanningProvider,
        PlanningRefusal,
        PlanningTaskEnded,
        PlanningTaskEvent;

import '../client/models.dart' show Project, defaultProject;
import 'machines.dart';
import 'owned_process.dart';
import 'planner_log_level.dart';
import 'window_log.dart' show LogLevel, windowLog;

/// Where the package puts the planner, which the window starts as it needs it.
const plannerInstalled = '/usr/libexec/porelo/planner';

/// The planner's name on the path, as a build of its own is called.
const plannerOnThePath = 'porelo-planner';

/// What the planning place says where this computer has no planner to start.
const plannerNotInstalled =
    'Planning comes from porelo-planner, which is not installed on this computer. '
    'Install the porelo-planner package and open Porelo again.';

/// What the planning place says on Windows, which porelo-planner is not built for.
const plannerNotOnWindows =
    'Planning comes from porelo-planner, which runs on Linux only for now. '
    'Planning is not offered in Porelo on Windows yet.';

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

/// Starts the planner at [executable] with [environment] added to the window's own, answering the process started.
typedef StartPlanner = Future<Process> Function(String executable, Map<String, String> environment);

/// The planner's option that has it end once its standard input closes, as when the window that holds it ends.
const plannerEndsWithInput = '--end-with-input';

/// Opens the planner's board reads from the address file under [runtimeDirectory], the account's own when null.
typedef OpenPlanner = Future<HttpPlanningSource> Function(PlannerProjects projects, {String? runtimeDirectory});

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

/// This computer's planner as the window's one provider of planning: found by its address file, started where none
/// runs, told each project's repository as the window knows it, and followed to a new address when the planner writes
/// one, as after a restart on another port.
class LocalPlanner extends ChangeNotifier
    implements PlanningClient, PlanningReach, NamesItsLog, TakesTheLogLevel, EndsWithTheWindow {
  /// Takes the projects the window knows and their repositories; [runtimeDirectory] is the one the planner writes its
  /// address under, `XDG_RUNTIME_DIR` when null, and [candidates] where the planner may be, in the order they are tried.
  /// [onWindows] is whether the window runs on Windows, where no planner is looked for or started.
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
    bool? onWindows,
    this._logLevel,
    TellPlannerLevel? tellLevel,
  }) : _onWindows = onWindows ?? Platform.isWindows,
       _tellLevel = tellLevel ?? tellPlannerLevel,
       _chosen = chosenProject,
       runtimeDirectory = runtimeDirectory == null || runtimeDirectory.trim().isEmpty ? null : runtimeDirectory,
       candidates = candidates ?? plannerCandidates(Platform.environment),
       _start = start ?? _startWithItsInput,
       _open = open ?? HttpPlanningSource.fromAddressFile {
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
    projects: () => plannedProjects(machines),
    repositories: (project) => plannerProjectOf(machines, project),
    chosenProject: () => machines.fleet.selectedProject?.name,
    changes: machines,
    runtimeDirectory: runtimeDirectory,
    candidates: candidates,
    start: start,
    open: open,
  );

  /// The provider's name, shown beside its answers.
  static const name = 'porelo-planner';

  /// The runtime directory the planner writes its address under, `XDG_RUNTIME_DIR` when null; a blank one is none.
  final String? runtimeDirectory;

  /// Where the planner may be, in the order they are tried.
  final List<String> candidates;

  /// How long the window waits for a planner it started to write its address.
  final Duration wait;

  /// How often it looks for that address meanwhile.
  final Duration poll;

  /// How often the address file of a planner found is read again, to follow the planner to a new address.
  final Duration follow;

  final List<String> Function() _projects;
  final PlannerProjects _repositories;
  final String? Function()? _chosen;
  final Listenable? _changes;
  final StartPlanner _start;
  final OpenPlanner _open;
  final bool _onWindows;
  final ValueListenable<LogLevel>? _logLevel;
  final TellPlannerLevel _tellLevel;
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

  /// The planner this window started, until it ended or was ended; null where the window found one serving.
  Process? _process;

  /// Where the planner this window started answers, as its address file said first after the start.
  _Answers? _startedAt;

  /// The exit code of the planner this window started, where it ended before it said where it answers.
  int? _endedEarly;

  @override
  String? get notReached => _notReached;

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
    if (_onWindows) return _say(plannerNotOnWindows);
    if (await _look() != _Look.notRunning) return;
    if (_started) {
      return _say('porelo-planner was started, but did not say where it answers yet.');
    }
    if (runtimeDirectory case final runtime? when !runtime.startsWith('/')) {
      return _say('porelo-planner cannot be started: its runtime directory $runtime is not an absolute path.');
    }
    final programs = candidates.where(_runnable).toList();
    if (programs.isEmpty) return _say(plannerNotInstalled);
    if (_disposed) return;
    if (await _startOneOf(programs) case final failure?) return _say('porelo-planner could not be started: $failure');
    final waited = Stopwatch()..start();
    while (!_disposed) {
      await Future<void>.delayed(poll);
      if (await _look() != _Look.notRunning) return;
      if (_endedEarly case final code?) {
        return _say('porelo-planner ended with exit code $code before it said where it answers.');
      }
      if (waited.elapsed >= wait) {
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
        _keep(await _start(program, {'XDG_RUNTIME_DIR': ?runtimeDirectory}));
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
      // The first address after the start is the started planner's: none answered before it.
      if (_process != null && _startedAt == null && address != null) _startedAt = _answersAt(address);
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
    final runtime = runtimeDirectory ?? Platform.environment['XDG_RUNTIME_DIR'];
    if (runtime == null || runtime.trim().isEmpty) return null;
    try {
      return await File('$runtime/porelo-planner/planner.json').readAsString();
    } on FileSystemException {
      return null;
    }
  }

  /// Reads the address file of the planner found again: a new address is opened in place of the old one, and a file
  /// gone at two reads in a row means that planner is gone, so the planner is looked for, and started, as at first.
  Future<void> _follow() async {
    if (_disposed || _checking || _source == null) return;
    _checking = true;
    try {
      final address = await _addressNow();
      if (_disposed) return;
      if (address != null) {
        _missing = 0;
        if (address != _address) await _look(quietly: true);
        return;
      }
      // Twice, so a planner writing its file anew is not taken for none.
      if (++_missing < 2) return;
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

  static bool _runnable(String path) {
    final stat = FileStat.statSync(path);
    return stat.type == FileSystemEntityType.file && stat.mode & 0x49 != 0;
  }

  /// Keeps the planner the window started, and says in the window's log how it ended.
  void _keep(Process process) {
    _process = process;
    _startedAt = null;
    _endedEarly = null;
    unawaited(
      process.exitCode.then((code) {
        if (!identical(_process, process)) return;
        _process = null;
        if (_startedAt == null) _endedEarly = code;
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
  Future<void> end() async {
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
    windowLog.info('Ending porelo-planner, which the window started.');
    try {
      await stopOwnedProcess(process);
      windowLog.info('porelo-planner, which the window started, ended with exit code ${await process.exitCode}.');
    } on TimeoutException {
      windowLog.error('porelo-planner, which the window started, did not end even on SIGKILL.');
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
  // answers its exit code; its output is read so it never blocks on a full pipe.
  static Future<Process> _startWithItsInput(String executable, Map<String, String> environment) async {
    final process = await Process.start(executable, const [plannerEndsWithInput], environment: environment);
    _intoTheLog(process.stdout, LogLevel.debug);
    _intoTheLog(process.stderr, LogLevel.info);
    return process;
  }

  static void _intoTheLog(Stream<List<int>> output, LogLevel level) => output
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(const LineSplitter())
      .listen((line) => windowLog.write(level, 'porelo-planner: $line'), onError: (Object _) {});
}

enum _Look { found, notRunning, refused }

/// Where a planner answers: the port and token its address file names.
typedef _Answers = (Object port, Object token);

/// Where the planner may be: where its package installs it, then on [environment]'s path, taking only absolute folders
/// that climb out of none.
List<String> plannerCandidates(Map<String, String> environment) => [
  plannerInstalled,
  for (final folder in (environment['PATH'] ?? '').split(':'))
    if (folder.startsWith('/') && !folder.split('/').contains('..')) '$folder/$plannerOnThePath',
];

/// The projects the watched machines list, each once, without the default project, which has no repository of its own.
List<String> plannedProjects(Machines machines) => {
  for (final machine in machines.all)
    for (final project in machines.of(machine).listedProjects)
      if (project.name != defaultProject) project.name,
}.toList();

/// Where [project]'s planning is kept, as the watched machines list it, the machine shown first.
PlannerProject plannerProjectOf(Machines machines, String project) {
  final all = machines.all;
  final shown = all.isEmpty ? null : machines.current;
  return plannerProjectIn([
    for (final machine in [?shown, ...all.where((machine) => machine != shown)]) ...machines.of(machine).listedProjects,
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
