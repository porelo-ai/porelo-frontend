import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'fleet_backend.dart';
import 'fleet_model.dart';
import 'machines.dart';

/// The priority limits offered above a board.
enum PlanningPriority {
  /// All reported priorities, including unknown ones.
  all('All priorities', null),

  /// Highest alone.
  highest('Highest only', 0),

  /// Highest and High.
  high('High and above', 1),

  /// Highest, High and Medium.
  medium('Medium and above', 2);

  const PlanningPriority(this.label, this.maximum);

  /// The label shown in the filter.
  final String label;

  /// The greatest rank included, or null for all.
  final int? maximum;
}

/// View choices retained for one project independently of its serving machine.
class PlanningPreferences {
  /// The priority limit.
  PlanningPriority priority = PlanningPriority.all;

  /// The search over identifier and title.
  String search = '';

  /// Whether closed states are shown.
  bool showClosed = false;

  /// Phase names folded to marks and counts, as in the design.
  final Set<String> foldedPhases = {'Ideas', 'Done'};

  /// State names folded to marks and counts.
  final Set<String> foldedStates = {'In analysis'};

  /// Stories whose issue lists are unfolded.
  final Set<String> expandedStories = {};
}

/// An unsaved destination, kept separately from the daemon's story state.
class PendingPlanningMove {
  /// Records the original state for the unsaved-move summary.
  PendingPlanningMove(this.from, this.to);

  /// The state when staging began.
  String from;

  /// The requested destination.
  final String to;

  /// The daemon's refusal, if this move failed.
  String? problem;
}

/// A project's board, replaced only by whole replies from its machine.
class PlanningBoard extends ChangeNotifier {
  /// Starts a watch with independently retained view choices.
  PlanningBoard(this.backend, this.project, {PlanningPreferences? preferences})
    : preferences = preferences ?? PlanningPreferences() {
    _listen();
  }

  /// The machine supplying the board.
  FleetBackend backend;

  /// The project name sent to that machine.
  String project;

  /// Choices belonging to the project.
  final PlanningPreferences preferences;

  /// The last whole reply, retained visibly stale after a failure.
  PlanningSnapshot? snapshot;

  /// The daemon's error, or an ended-watch explanation.
  String? problem;

  /// Whether the daemon explicitly lacks this feature.
  bool unsupported = false;

  /// Whether changes are still arriving.
  bool live = false;
  final Map<String, PendingPlanningMove> _pending = {};

  /// Unsaved moves in staging order.
  Map<String, PendingPlanningMove> get pending => Map.unmodifiable(_pending);

  /// Whether a save or reload is in progress.
  bool saving = false;

  /// Save, reload, or drop feedback, using daemon details on failures.
  String? moveProblem;

  (FleetBackend, String)? _queuedProject;
  (PlanningSnapshot, int)? _deferredSnapshot;
  int _replyOrder = 0;
  int _snapshotOrder = 0;
  StreamSubscription<PlanningSnapshot>? _watching;
  bool _disposed = false;
  int _generation = 0;

  void _listen() {
    final generation = ++_generation;
    bool current() => !_disposed && generation == _generation;
    try {
      _watching = backend
          .watchStories(project)
          .listen(
            (reply) {
              if (!current()) return;
              final order = ++_replyOrder;
              if (saving) {
                if (reply.complete && reply.revision.isNotEmpty) _deferredSnapshot = (reply, order);
              } else {
                _accept(reply, order: order);
              }
              problem = null;
              unsupported = false;
              live = true;
              notifyListeners();
            },
            onError: (Object error) {
              if (!current()) return;
              final watching = _watching;
              _watching = null;
              unsupported = error is FeatureNotSupported || error is VarlinkException && error.isMethodNotFound;
              problem = unsupported ? null : _failureWords(error);
              live = false;
              notifyListeners();
              // A retry can start without waiting again on this terminal subscription's cancellation.
              unawaited(watching?.cancel());
            },
            onDone: () {
              if (!current()) return;
              _watching = null;
              live = false;
              if (!unsupported) problem ??= 'The planning watch ended. The board is no longer live.';
              notifyListeners();
            },
          );
    } catch (error) {
      unsupported = error is FeatureNotSupported || error is VarlinkException && error.isMethodNotFound;
      problem = unsupported ? null : _failureWords(error);
      live = false;
    }
  }

  String _failureWords(Object error) {
    if (error is VarlinkException) {
      final detail = error.parameters['detail'];
      if (detail is String && detail.trim().isNotEmpty) return detail;
      final message = error.parameters['message'];
      if (message is String && message.trim().isNotEmpty) return message;
      return 'Refused: ${error.simpleName}.';
    }
    return '$error';
  }

  /// Replaces the source, canceling its silent watch before accepting another project's replies.
  Future<void> changeProject(FleetBackend next, String name) async {
    if (_disposed) return;
    if (saving) {
      _queuedProject = (next, name);
      return;
    }
    final sameProject = identical(backend, next) && project == name;
    final generation = ++_generation;
    final watching = _watching;
    _watching = null;
    if (watching != null) await watching.cancel();
    if (_disposed || generation != _generation) return;
    backend = next;
    project = name;
    if (!sameProject) {
      snapshot = null;
      _pending.clear();
      moveProblem = null;
    }
    problem = null;
    unsupported = false;
    live = false;
    _listen();
    notifyListeners();
  }

  /// Restarts this project's watch after a failure, retaining its last snapshot and view choices.
  Future<void> retry() => changeProject(backend, project);

  /// The displayed destination, with failed moves kept in their reported state.
  String displayedState(PlanStory story) {
    final move = _pending[story.id];
    final destination = move == null ? null : state(move.to);
    return move != null &&
            move.problem == null &&
            destination != null &&
            phases.any((phase) => phase.states.contains(move.to))
        ? move.to
        : story.state;
  }

  /// Stages a waiting or closed destination without sending any command.
  void move(String id, String to) {
    if (_disposed || saving || snapshot?.complete != true || !live) return;
    final story = stories.where((story) => story.id == id).firstOrNull;
    final target = state(to);
    if (story == null || target == null) return;
    if (target.kind == 'WORKING') return;
    if (snapshot!.revision.isEmpty) {
      moveProblem = 'The machine did not report a planning revision. Reload planning before moving stories.';
      _changed();
      return;
    }
    if (to == story.state) {
      undo(id);
      return;
    }
    _pending[id] = PendingPlanningMove(story.state, to);
    _changed();
  }

  /// Drops one unsaved move without touching the daemon.
  void undo(String id) {
    if (_disposed || saving) return;
    _pending.remove(id);
    if (_pending.isEmpty) moveProblem = null;
    _changed();
  }

  /// Drops all unsaved moves without touching the daemon.
  void undoAll() {
    if (_disposed || saving) return;
    _pending.clear();
    moveProblem = null;
    _changed();
  }

  PlanningSnapshot _checked(PlanningSnapshot reply) {
    if (!reply.complete || reply.revision.isEmpty) {
      throw StateError('The machine did not report a complete planning board and revision.');
    }
    return reply;
  }

  Future<(PlanningSnapshot, int)> _read() async {
    final workflow = await backend.planningWorkflow(project);
    if (_disposed) throw StateError('The planning board was closed.');
    final reply = await backend.stories(project);
    final order = ++_replyOrder;
    return (_checked(PlanningSnapshot.fromParts(workflow, reply)), order);
  }

  void _accept(PlanningSnapshot reply, {required int order, bool reconcile = true}) {
    if (order <= _snapshotOrder) return;
    snapshot = reply;
    _snapshotOrder = order;
    if (!reconcile || !reply.complete || reply.revision.isEmpty) return;
    final reconciled = <String>[];
    for (final entry in _pending.entries.toList()) {
      final story = reply.stories.where((story) => story.id == entry.key).firstOrNull;
      if (story == null) {
        _pending.remove(entry.key);
        reconciled.add('${entry.key} is no longer reported by the machine.');
      } else if (story.state == entry.value.to) {
        _pending.remove(entry.key);
        reconciled.add('${entry.key} was moved to ${entry.value.to} elsewhere.');
      } else {
        entry.value.from = story.state;
      }
    }
    if (reconciled.isNotEmpty) {
      final detail = reconciled.join(' ');
      moveProblem = moveProblem == null ? detail : '$moveProblem $detail';
    }
  }

  void _finishOperation() {
    if (_disposed) return;
    saving = false;
    final deferred = _deferredSnapshot;
    _deferredSnapshot = null;
    if (deferred != null && deferred.$1.complete && deferred.$1.revision.isNotEmpty && deferred.$2 > _snapshotOrder) {
      _accept(deferred.$1, order: deferred.$2);
    }
    _changed();
    final queued = _queuedProject;
    _queuedProject = null;
    if (queued != null) unawaited(changeProject(queued.$1, queued.$2));
  }

  /// Reloads and reconciles pending destinations while retaining their individual refusals.
  Future<void> reload() async {
    if (_disposed || saving) return;
    saving = true;
    final generation = _generation;
    _changed();
    try {
      final reply = await _read();
      if (_disposed || generation != _generation) return;
      moveProblem = null;
      _accept(reply.$1, order: reply.$2);
    } catch (error) {
      if (!_disposed && generation == _generation) moveProblem = _failureWords(error);
    } finally {
      _finishOperation();
    }
  }

  /// Saves all pending stories atomically and applies only the daemon's complete answer.
  Future<void> save() async {
    if (_disposed || saving || _pending.isEmpty || !live) return;
    saving = true;
    final generation = _generation;
    final revision = snapshot?.revision ?? '';
    final moves = [for (final entry in _pending.entries) PlanningStoryMove(entry.key, entry.value.to)];
    moveProblem = null;
    for (final move in _pending.values) {
      move.problem = null;
    }
    _changed();
    try {
      _checked(snapshot!);
      final reply = await backend.moveStories(project, moves, revision);
      final order = ++_replyOrder;
      if (_disposed || generation != _generation) return;
      _checked(reply);
      if (!reply.moved) throw StateError('The machine did not confirm the planning moves.');
      for (final move in moves) {
        final story = reply.stories.where((story) => story.id == move.story).firstOrNull;
        if (story?.state == move.to) {
          _pending.remove(move.story);
        } else {
          _pending[move.story]?.problem = 'The machine did not confirm this destination.';
        }
      }
      _accept(reply, order: order, reconcile: false);
    } on VarlinkException catch (error) {
      if (_disposed || generation != _generation) return;
      final detail = _failureWords(error);
      final named = error.parameters['story'];
      final affected = named is String && moves.any((move) => move.story == named)
          ? moves.where((move) => move.story == named).toList()
          : moves;
      for (final move in affected) {
        _pending[move.story]?.problem = detail;
      }
      if (error.simpleName == 'PlanningChanged') {
        moveProblem = detail;
        try {
          final reply = await _read();
          if (!_disposed && generation == _generation) _accept(reply.$1, order: reply.$2);
        } catch (readError) {
          if (!_disposed && generation == _generation) moveProblem = '$detail ${_failureWords(readError)}';
        }
      }
    } catch (error) {
      if (!_disposed && generation == _generation) moveProblem = _failureWords(error);
    } finally {
      _finishOperation();
    }
  }

  /// The reported states, without inventing any workflow.
  List<PlanState> get states => snapshot?.states ?? const [];

  /// The reported phases.
  List<PlanPhase> get phases => snapshot?.phases ?? const [];

  /// The reported stories, independent of the filters.
  List<PlanStory> get stories => snapshot?.stories ?? const [];

  /// Stories in states the daemon calls WORKING, or null before a snapshot or after losing the watch.
  int? get workingCount =>
      snapshot?.complete != true || !live || stories.any((story) => state(story.state)?.kind.isEmpty ?? true)
      ? null
      : stories.where((story) => state(story.state)?.kind == 'WORKING').length;

  /// The reported state with this name, if any.
  PlanState? state(String name) => states.where((state) => state.name == name).firstOrNull;

  /// Whether a state is shown under the closed-state choice.
  bool visible(PlanState state) => preferences.showClosed || state.kind != 'CLOSED';

  /// Visible states of a phase, working first and otherwise in workflow order.
  List<PlanState> statesIn(PlanPhase phase) {
    final listed = states.where((state) => phase.states.contains(state.name) && visible(state)).toList();
    return [...listed.where((state) => state.kind == 'WORKING'), ...listed.where((state) => state.kind != 'WORKING')];
  }

  /// The number of closed stories before filtering.
  int? get closedCount => snapshot?.complete != true || stories.any((story) => state(story.state)?.kind.isEmpty ?? true)
      ? null
      : stories.where((story) => state(story.state)?.kind == 'CLOSED').length;

  /// The priority rank, with unknown or missing values after known ones.
  static int rank(String priority) => switch (priority) {
    'Highest' => 0,
    'High' => 1,
    'Medium' => 2,
    'Low' => 3,
    _ => 4,
  };
  bool _matches(PlanStory story) {
    final query = preferences.search.trim().toLowerCase();
    return (preferences.priority.maximum == null || rank(story.priority) <= preferences.priority.maximum!) &&
        (query.isEmpty || story.id.toLowerCase().contains(query) || story.title.toLowerCase().contains(query));
  }

  List<PlanStory> _sort(Iterable<PlanStory> stories) => stories.where(_matches).toList()
    ..sort((a, b) {
      final priority = rank(a.priority).compareTo(rank(b.priority));
      if (priority != 0) return priority;
      int? number(String id) => int.tryParse(RegExp(r'\d+$').firstMatch(id)?.group(0) ?? '');
      final left = number(a.id), right = number(b.id);
      return left != null && right != null && left != right ? left.compareTo(right) : a.id.compareTo(b.id);
    });

  /// The filtered, sorted stories of exactly this reported state.
  List<PlanStory> cards(String name) => _sort(stories.where((story) => displayedState(story) == name));

  /// Stories whose state is missing from the column configuration, kept visible with an explanation.
  List<PlanStory> get unplaced => _sort(
    stories.where(
      (story) =>
          state(displayedState(story)) == null || !phases.any((phase) => phase.states.contains(displayedState(story))),
    ),
  );

  /// Updates the priority filter.
  void filter(PlanningPriority priority) {
    preferences.priority = priority;
    _changed();
  }

  /// Updates the search.
  void search(String query) {
    preferences.search = query;
    _changed();
  }

  /// Toggles closed states.
  void toggleClosed() {
    preferences.showClosed = !preferences.showClosed;
    _changed();
  }

  /// Toggles one phase.
  void foldPhase(String name) {
    _toggle(preferences.foldedPhases, name);
  }

  /// Toggles one state.
  void foldState(String name) {
    _toggle(preferences.foldedStates, name);
  }

  /// Toggles one story's issue list.
  void expand(String id) {
    _toggle(preferences.expandedStories, id);
  }

  void _toggle(Set<String> set, String name) {
    if (!set.remove(name)) set.add(name);
    _changed();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_watching?.cancel());
    super.dispose();
  }
}

/// Keeps boards for watched projects and selects an available planning provider.
class PlanningBoards extends ChangeNotifier {
  /// Observes the fleet without opening sockets in the frame.
  PlanningBoards(this.machines) {
    machines.addListener(_sync);
    _sync();
  }

  /// The watched machines.
  final Machines machines;
  final Map<(String, String), PlanningBoard> _boards = {};
  final Map<String, PlanningPreferences> _preferences = {};
  String? _selected;
  bool _disposed = false;
  final Map<String, bool> _connected = {};

  void _sync() {
    if (_disposed) return;
    final wanted = <(String, String), FleetBackend>{
      for (final machine in machines.all)
        for (final project in machines.of(machine).listedProjects)
          if (machines.of(machine).reachability == Reachability.connected ||
              _boards.containsKey((machine.name, project.name)))
            (machine.name, project.name): machines.of(machine).backend,
    };
    for (final key in _boards.keys.toList()) {
      if (!wanted.containsKey(key) || !identical(_boards[key]!.backend, wanted[key])) {
        _boards.remove(key)!.dispose();
      }
    }
    for (final entry in wanted.entries) {
      if (_boards[entry.key] case final existing?) {
        final connected = machines.all.any(
          (machine) => machine.name == entry.key.$1 && machines.of(machine).reachability == Reachability.connected,
        );
        if (connected && _connected[entry.key.$1] == false) {
          unawaited(existing.changeProject(entry.value, entry.key.$2));
        }
        continue;
      }
      final board = PlanningBoard(
        entry.value,
        entry.key.$2,
        preferences: _preferences.putIfAbsent(entry.key.$2, PlanningPreferences.new),
      );
      board.addListener(_changed);
      _boards[entry.key] = board;
    }
    _connected
      ..clear()
      ..addEntries(
        machines.all.map(
          (machine) => MapEntry(machine.name, machines.of(machine).reachability == Reachability.connected),
        ),
      );
    _changed();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  /// Boards holding unsaved work, including providers no longer selected.
  Iterable<PlanningBoard> get pendingBoards =>
      _boards.values.where((board) => board.pending.isNotEmpty || board.saving);

  /// The project names with at least one provider that has not refused planning.
  List<String> get projects =>
      _boards.entries.where((entry) => !entry.value.unsupported).map((entry) => entry.key.$2).toSet().toList();

  /// The selected board, preferring the current machine whenever it offers planning.
  PlanningBoard? get selected {
    final available = projects;
    final name = available.contains(_selected)
        ? _selected
        : available.contains(machines.fleet.selectedProject?.name)
        ? machines.fleet.selectedProject?.name
        : available.firstOrNull;
    if (name == null) {
      return _boards.entries.where((entry) => entry.key.$1 == machines.current.name).firstOrNull?.value ??
          _boards.values.firstOrNull;
    }
    return _provider(name);
  }

  PlanningBoard? _provider(String name) {
    final candidates = _boards.values.where((board) => board.project == name && !board.unsupported).toList();
    final preferred = _boards[(machines.current.name, name)];
    bool current(PlanningBoard board) => board.live && board.snapshot?.complete == true;
    bool holdsPending(PlanningBoard board) => board.pending.isNotEmpty || board.saving;
    if (preferred != null && !preferred.unsupported && holdsPending(preferred)) return preferred;
    final pending = candidates.where(holdsPending).firstOrNull;
    if (pending != null) return pending;
    if (preferred != null && !preferred.unsupported && current(preferred)) return preferred;
    return candidates.where(current).firstOrNull ??
        (preferred != null && !preferred.unsupported ? preferred : candidates.firstOrNull);
  }

  /// Errors from other providers of the selected project, retained even while a live provider supplies it.
  List<String> get providerProblems {
    final shown = selected;
    return [
      for (final board in _boards.values)
        if (!identical(board, shown) && board.project == shown?.project && board.problem != null)
          '${board.backend.label}: ${board.problem}',
    ];
  }

  /// Selects a project without resetting its view choices.
  void select(String name) {
    _selected = name;
    _changed();
  }

  /// The total from one planning provider per project, unknown while any included board is stale or unread.
  int? get workingCount {
    var count = 0;
    if (_boards.isEmpty || projects.isEmpty) return null;
    for (final project in projects) {
      final working = _provider(project)?.workingCount;
      if (working == null) return null;
      count += working;
    }
    return count;
  }

  @override
  void dispose() {
    _disposed = true;
    machines.removeListener(_sync);
    for (final board in _boards.values) {
      board.dispose();
    }
    _boards.clear();
    super.dispose();
  }
}
