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
}

/// This computer's planner as the window's one provider of planning: found by its address file, started once where
/// none runs, told each project's repository as the window knows it.
class LocalPlanner extends ChangeNotifier implements PlanningClient, PlanningReach {
  /// Takes the projects the window knows and their repositories; [runtimeDirectory] is the one the planner writes its
  /// address under, `XDG_RUNTIME_DIR` when null, and [candidates] where the planner may be, in the order they are tried.
  LocalPlanner({
    required this._projects,
    required this._repositories,
    String? Function()? chosenProject,
    this._changes,
    this.runtimeDirectory,
    List<String>? candidates,
    StartPlanner? start,
    OpenPlanner? open,
    this.wait = const Duration(seconds: 20),
    this.poll = const Duration(milliseconds: 200),
  }) : _chosen = chosenProject,
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

  /// The runtime directory the planner writes its address under, `XDG_RUNTIME_DIR` when null.
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

  Future<void>? _reaching;
  HttpPlanningSource? _source;
  String? _notReached = plannerLookedFor;
  bool _disposed = false;

  /// Whether this window started a planner; it starts at most one in its life.
  bool get started => _started;
  bool _started = false;

  @override
  String? get notReached => _notReached;

  /// Finds the planner, starting it where none runs; asked again, it answers the first try's end.
  Future<void> reach() => _reaching ??= _reach();

  Future<void> _reach() async {
    if (await _found()) return;
    if (_notReached != plannerLookedFor) return;
    final program = candidates.where(_runnable).firstOrNull;
    if (program == null) return _say(plannerNotInstalled);
    try {
      _started = true;
      await _start(program, {'XDG_RUNTIME_DIR': ?runtimeDirectory});
    } on Object catch (error) {
      return _say('porelo-planner could not be started: $error');
    }
    final waited = Stopwatch()..start();
    while (!_disposed) {
      await Future<void>.delayed(poll);
      if (await _found() || _notReached != plannerLookedFor) return;
      if (waited.elapsed >= wait) {
        return _say('porelo-planner was started, but did not say where it answers within ${wait.inSeconds} s.');
      }
    }
  }

  /// Whether the planner's address was read; a refusal other than a missing address is said and ends the search.
  Future<bool> _found() async {
    try {
      final source = await _open(_repositories, runtimeDirectory: runtimeDirectory);
      if (_disposed) {
        source.close();
        return true;
      }
      _source = source;
      _notReached = null;
      notifyListeners();
      return true;
    } on PlanningRefusal catch (refusal) {
      if (refusal.name != 'NoAddress') _say('porelo-planner cannot be reached: $refusal');
      return false;
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

  /// Nothing to tell: the planner takes no report of the window's tasks.
  @override
  Future<void> taskEvent(String project, String task, PlanningTaskEvent event) async {}

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

/// Where the planner may be: where its package installs it, then on [environment]'s path.
List<String> plannerCandidates(Map<String, String> environment) => [
  plannerInstalled,
  for (final folder in (environment['PATH'] ?? '').split(':'))
    if (folder.startsWith('/')) '$folder/$plannerOnThePath',
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

/// Where [project]'s planning is kept: the upstream of its own repository, from the first of [known] that names one;
/// refused in words where none does.
PlannerProject plannerProjectIn(Iterable<Project> known, String project) {
  for (final listed in known.where((each) => each.name == project)) {
    final own = listed.ownRepository;
    final upstream = listed.repositoryStates.where((each) => each.name == own).firstOrNull?.upstream.trim() ?? '';
    if (upstream.isNotEmpty) return PlannerProject(upstream);
  }
  throw PlanningRefusal(
    'NoRepository',
    {'project': project},
    'No watched machine names where $project\'s own repository is followed from, so porelo-planner cannot be told '
        'where its planning is kept.',
  );
}
