import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:porelo_planning/porelo_planning.dart'
    show
        HttpPlanningSource,
        PlannerProject,
        PlannerProjects,
        PlanningClient,
        PlanningProvider,
        PlanningRefusal,
        PlanningTaskEnded,
        PlanningTaskEvent;

import '../client/models.dart' show Project, defaultProject;
import 'machines.dart';

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

/// Starts the planner at [executable] with [environment] added to the window's own, returning once it was started.
typedef StartPlanner = Future<void> Function(String executable, Map<String, String> environment);

/// Opens the planner's board reads from the address file under [runtimeDirectory], the account's own when null.
typedef OpenPlanner = Future<HttpPlanningSource> Function(PlannerProjects projects, {String? runtimeDirectory});

/// A planning client that may not have reached its planning yet, and says why.
abstract interface class PlanningReach implements Listenable {
  /// What the planning place says instead of a board, or null once planning is reached.
  String? get notReached;

  /// Tries again to reach planning, as when the person refreshes.
  Future<void> reach();
}

/// This computer's planner as the window's one provider of planning: found by its address file, started once where
/// none runs, told each project's repository as the window knows it.
class LocalPlanner extends ChangeNotifier implements PlanningClient, PlanningReach {
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
    bool? onWindows,
  }) : _onWindows = onWindows ?? Platform.isWindows,
       _chosen = chosenProject,
       runtimeDirectory = runtimeDirectory == null || runtimeDirectory.trim().isEmpty ? null : runtimeDirectory,
       candidates = candidates ?? plannerCandidates(Platform.environment),
       _start = start ?? _startDetached,
       _open = open ?? HttpPlanningSource.fromAddressFile {
    _changes?.addListener(notifyListeners);
  }

  /// The watched machines' projects, each told to the planner with its own repository's upstream as its clone URL.
  factory LocalPlanner.of(
    Machines machines, {
    String? runtimeDirectory,
    List<String>? candidates,
    StartPlanner? start,
    OpenPlanner? open,
  }) => LocalPlanner(
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

  final List<String> Function() _projects;
  final PlannerProjects _repositories;
  final String? Function()? _chosen;
  final Listenable? _changes;
  final StartPlanner _start;
  final OpenPlanner _open;
  final bool _onWindows;

  Future<void>? _reaching;
  HttpPlanningSource? _source;
  String? _notReached = plannerLookedFor;
  bool _disposed = false;

  /// Whether this window started a planner; it starts at most one in its life.
  bool get started => _started;
  bool _started = false;

  @override
  String? get notReached => _notReached;

  /// Finds the planner, starting it where none runs; asked while it looks, it answers that look's end, and asked
  /// after a failed look, it looks again, never starting a second planner.
  @override
  Future<void> reach() => _reaching ??= _reach().whenComplete(() {
    if (_source == null) _reaching = null;
  });

  Future<void> _reach() async {
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
    if (await _startOneOf(programs) case final failure?) return _say('porelo-planner could not be started: $failure');
    final waited = Stopwatch()..start();
    while (!_disposed) {
      await Future<void>.delayed(poll);
      if (await _look() != _Look.notRunning) return;
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
        await _start(program, {'XDG_RUNTIME_DIR': ?runtimeDirectory});
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

  /// Reads the planner's address; only a missing one means no planner runs, every other failure is said.
  Future<_Look> _look() async {
    try {
      final source = await _open(_repositories, runtimeDirectory: runtimeDirectory);
      if (_disposed) {
        source.close();
        return _Look.found;
      }
      _source = source;
      _notReached = null;
      notifyListeners();
      return _Look.found;
    } on PlanningRefusal catch (refusal) {
      if (refusal.name == 'NoAddress') return _Look.notRunning;
      _say('porelo-planner cannot be reached: $refusal');
      return _Look.refused;
    } on Object catch (error) {
      _say('porelo-planner cannot be reached: $error');
      return _Look.refused;
    }
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

  /// Nothing told yet: the window reports none of its tasks so far.
  @override
  Future<void> taskEvent(
    String project,
    String task,
    PlanningTaskEvent event, {
    required String offer,
    required String container,
    required String machine,
    PlanningTaskEnded? ended,
  }) async {}

  @override
  void dispose() {
    _disposed = true;
    _changes?.removeListener(notifyListeners);
    _source?.close();
    super.dispose();
  }

  static bool _runnable(String path) {
    final stat = FileStat.statSync(path);
    return stat.type == FileSystemEntityType.file && stat.mode & 0x49 != 0;
  }

  // Detached, so the planner keeps serving the account's other windows and tools after this one closes.
  static Future<void> _startDetached(String executable, Map<String, String> environment) =>
      Process.start(executable, const [], environment: environment, mode: ProcessStartMode.detached);
}

enum _Look { found, notRunning, refused }

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
