import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'clearance.dart';
import 'authorizations.dart';
import 'mailboxes.dart';
import 'fleet_backend.dart';
import 'outcome_words.dart';

/// Whether the interface can currently reach the backend it is pointed at.
enum Reachability {
  /// Opening the socket, or asking what is there.
  connecting,

  /// Answering.
  connected,

  /// Nothing there, or the tunnel went away. Never the same thing as an empty machine.
  unreachable,

  /// Reachable, but serving no interface this build understands.
  incompatible,
}

/// One project and the work under it, as the frame draws them.
///
/// The project itself is the daemon's — assembled from the gate mirrors, the tasks that exist and
/// the files task starts recorded. Only the pairing with its tasks is done here.
@immutable
class ProjectOnScreen {
  /// Constructor taking the project and the work under it.
  const ProjectOnScreen({required this.project, required this.tasks});

  /// What the daemon says the project is.
  final Project project;

  /// Its tasks, running or not.
  final List<Task> tasks;

  /// Name as the daemon reports it.
  String get name => project.name;

  /// What to call it on screen.
  String get label => name.isEmpty
      ? 'No project recorded'
      : name == defaultProject
      ? 'default — work without a project'
      : name;

  /// How many of its tasks are up, and how many it has.
  ///
  /// The daemon's own counts, not a count of [tasks]: it assembles them from the gate mirrors,
  /// the tasks that exist and the recorded project files, and knows about work this end may not
  /// have matched by name. Derive nothing here that the far end already knows.
  int get running => project.running;

  /// How many tasks it has, running or stopped.
  int get howMuchWork => project.tasks;

  /// Whether anything can be done to it beyond looking at it.
  bool get canBeActedOn => project.canBeActedOn;
}

/// A `Stop` that came back refusing, and what it said.
///
/// A refusal is the product working, not an error path: it needs a real place in the interface
/// where what is held is legible and the choice about it is made deliberately. It is never
/// softened into a "force" that quietly discards somebody's afternoon.
@immutable
class Refusal {
  /// Constructor taking which task refused and what it answered.
  const Refusal({required this.task, required this.result});

  /// The task that was left exactly as it was.
  final String task;

  /// What `Remove` answered, including what the task holds.
  final Removed result;

  /// Whether the task holds commits that never reached the gate.
  bool get holdsWork => result.outcome == Outcome.holdsWork;

  /// Whether nothing could say what it holds.
  bool get nothingKnows => result.outcome == Outcome.nothingKnows;

  /// Whether it is still running, which a removal needs it not to be.
  bool get stillRunning => result.outcome == Outcome.stillRunning;
}

/// What the interface knows about one backend, and the selections made over it.
///
/// Everything the shell renders comes from here, so there is one place that knows whether the
/// machine is reachable — and one place that keeps the last answer when it stops being.
class FleetModel extends ChangeNotifier {
  /// Constructor taking the backend to talk to.
  ///
  /// [retryAfter] is how long to wait before trying a machine that stopped answering. A tunnel
  /// that drops has to recover without anybody restarting the interface, so this is a loop and
  /// not a button — the button is there as well, for somebody who does not want to wait.
  FleetModel(this.backend, {this.retryAfter = const Duration(seconds: 2)}) {
    // Once, here: connect() runs again on every reconnect, and each listener it added stayed.
    clearance.addListener(_notify);
    mailboxes.addListener(_notify);
    authorizations.addListener(_notify);
  }

  /// Which machine this is.
  final FleetBackend backend;

  /// How long to wait before trying a machine that stopped answering.
  final Duration retryAfter;

  /// Blocked connections on this machine, watched for as long as it is.
  ///
  /// Per machine and not per selection: a question has a deadline and is never asked twice, so a
  /// machine somebody happens not to be looking at is exactly the one whose work expires unseen.
  final clearance = Clearance();

  /// Messages on this machine that wait for a person, asked of the machine for as long as it is
  /// watched: a held message waits for somebody, and the machine nobody looks at is where it waits.
  final mailboxes = Mailboxes();

  /// What a person has to authorize on this machine before work can use it, for as long as it is
  /// watched: the question waits for somebody, and not only for whoever started the work.
  final authorizations = Authorizations();

  ServiceInfo? _info;
  StreamSubscription<List<Task>>? _watching;
  Timer? _retry;
  bool _disposed = false;

  Reachability _reachability = Reachability.connecting;
  String _status = 'Starting up.';
  bool _busy = false;
  bool _live = false;
  List<Task> _tasks = const <Task>[];
  List<Project> _known = const <Project>[];
  String? _selectedProject;
  String? _selectedTask;
  Refusal? _refusal;
  final Map<String, String> _said = <String, String>{};

  /// Whether the backend is answering.
  Reachability get reachability => _reachability;

  /// Completes once connecting is over, answered or not: what asks the daemon right after a
  /// machine was added waits for this rather than asking a socket that is not open yet.
  Future<void> untilAsked() {
    if (_reachability != Reachability.connecting) return Future<void>.value();
    final over = Completer<void>();
    void check() {
      if (_reachability == Reachability.connecting || over.isCompleted) return;
      removeListener(check);
      over.complete();
    }

    addListener(check);
    return over.future;
  }

  /// The last thing that happened, in words, for the status line.
  String get status => _status;

  /// The last thing an action on [task] came to, in words, or null when nothing was done to it.
  String? saidAbout(String task) => _said[task];

  /// Whether something is running now. Deliberately separate from [status], which has to stay
  /// readable while it does.
  bool get busy => _busy;

  /// Whether the task list is arriving by itself. False against a backend without `Watch`.
  bool get liveUpdates => _live;

  /// What the backend said it is, once connected.
  ServiceInfo? get info => _info;

  /// Every task on the machine, as last answered.
  List<Task> get tasks => _tasks;

  /// Every project the daemon lists, each with the work under it.
  ///
  /// Asked for rather than derived from the task list. A project that has never run anything is
  /// invisible to a client that derives them, and that is the project most likely to need
  /// attention.
  List<ProjectOnScreen> get projects {
    final under = <String, List<Task>>{};
    for (final task in _tasks) {
      under.putIfAbsent(task.project, () => <Task>[]).add(task);
    }
    final screen =
        <ProjectOnScreen>[
          for (final project in _known)
            ProjectOnScreen(
              project: project,
              tasks: (under.remove(project.name) ?? <Task>[])..sort((a, b) => a.name.compareTo(b.name)),
            ),
        ]..sort(
          (a, b) => a.name == defaultProject
              ? -1
              : b.name == defaultProject
              ? 1
              : a.name.compareTo(b.name),
        );

    // Whatever is left belongs to no project the daemon lists — a task that recorded no project,
    // or one recorded under a name it no longer knows. Listing it is the point: work that belongs
    // nowhere is not work that stops existing.
    for (final orphaned in under.entries) {
      screen.add(
        ProjectOnScreen(
          project: Project(
            name: orphaned.key,
            securityClass: orphaned.value.first.securityClass,
            file: '',
            mirror: '',
            pending: 0,
            tasks: orphaned.value.length,
            running: orphaned.value.where((task) => task.running).length,
          ),
          tasks: orphaned.value..sort((a, b) => a.name.compareTo(b.name)),
        ),
      );
    }
    return screen;
  }

  /// The selected project, or null before anything is chosen.
  ProjectOnScreen? get selectedProject {
    final name = _selectedProject;
    if (name == null) return null;
    for (final project in projects) {
      if (project.name == name) return project;
    }
    return null;
  }

  /// The selected task, or null when none is.
  Task? get selectedTask {
    final name = _selectedTask;
    if (name == null) return null;
    for (final task in _tasks) {
      if (task.name == name) return task;
    }
    return null;
  }

  /// The work under the selected project.
  List<Task> get workInView => selectedProject?.tasks ?? const <Task>[];

  /// Opens the backend, reads what is there and follows it.
  Future<void> connect() async {
    _reachability = Reachability.connecting;
    _say('Connecting to ${backend.label}.');
    try {
      final info = await backend.open();
      _info = info;
      _retry?.cancel();
      _reachability = Reachability.connected;
      _say('Connected to ${backend.label}, ${info.product} ${info.version}.');
      await _readOnce();
      // Dropped while it was connecting — a stored list replacing the machine the window opened
      // with does that. Following now would listen through what dispose() already closed.
      if (_disposed) return;
      _follow();
      clearance.watch(backend);
      mailboxes.watch(backend);
      authorizations.watch(backend);
    } on VarlinkDisconnected catch (ex) {
      _reachability = Reachability.unreachable;
      _say('Cannot reach ${backend.label}: ${ex.message}');
      _tryAgainLater();
    } on StateError catch (ex) {
      _reachability = Reachability.incompatible;
      _say(ex.message);
    }
  }

  /// Asks again now, for a backend that cannot tell us by itself.
  ///
  /// [quietly] is for asking again in the background: nothing said, nothing drawn as busy.
  Future<void> refresh({bool quietly = false}) async {
    if (_info == null) {
      await connect();
      return;
    }
    if (quietly) {
      await _readOnce();
      return;
    }
    _busy = true;
    _notify();
    try {
      await _readOnce();
      _say('Refreshed: ${_tasks.length} ${_tasks.length == 1 ? 'task' : 'tasks'}.');
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Selects a project. Selecting never changes anything about it.
  void selectProject(String? name) {
    if (_selectedProject == name) return;
    _selectedProject = name;
    _selectedTask = null;
    _notify();
  }

  /// A `Stop` that refused, until it is answered or dismissed.
  Refusal? get refusal => _refusal;

  /// Stops a task, keeping it: its container is its workspace, and removing is [removeWork].
  Future<void> stopWork(String task) async {
    await _acting(about: task, () async {
      _say(stopWords(task, await backend.stopTask(task)));
      await _readOnce();
    });
  }

  /// Removes a task, or takes the refusal and keeps it for somebody to decide about.
  ///
  /// [rescue] pushes what it holds into the mirror first; [force] stops it if it runs and
  /// discards what never reached the gate. Neither is a default.
  Future<void> removeWork(String task, {bool rescue = false, bool force = false}) async {
    await _acting(about: task, () async {
      final result = await backend.removeTask(task, rescue: rescue ? true : null, force: force ? true : null);
      _say(removeWords(task, result));
      _refusal = result.removed ? null : Refusal(task: task, result: result);
      await _readOnce();
    });
  }

  /// Removes a task, stopping it first only once the machine has said it holds nothing.
  ///
  /// **Asked while it still runs.** A running task that holds work answers `HOLDS_WORK`, and the
  /// rescue that offers needs the container up; stopping first would leave nothing to rescue from.
  /// `STILL_RUNNING` means it holds nothing, so it is stopped and removed.
  Future<void> removeEvenIfRunning(String task) async {
    await removeWork(task);
    if (_refusal?.stillRunning ?? false) {
      _refusal = null;
      await stopAndRemove(task);
    }
  }

  /// Stops a task and then removes it: the answer to a removal refused because it still runs.
  Future<void> stopAndRemove(String task) async {
    await stopWork(task);
    await removeWork(task);
  }

  /// Takes a task down so it can be created again from scratch. Answers whether the way is clear.
  ///
  /// **The removal can refuse, and then nothing is started.** `Remove` answers `HOLDS_WORK` for a
  /// task with commits that never reached the gate; starting after it would lose the reason.
  ///
  /// The point of recreating is a **newly built environment**: a task keeps the image it started
  /// with, so picking up a new one means being created again rather than started again.
  Future<bool> clearTheWayToRecreate(String task) async {
    var cleared = false;
    await _acting(about: task, () async {
      if (_tasks.any((each) => each.name == task && each.running)) {
        _say(stopWords(task, await backend.stopTask(task)));
      }
      final removed = await backend.removeTask(task);
      _say(removeWords(task, removed));
      _refusal = removed.removed ? null : Refusal(task: task, result: removed);
      cleared = removed.removed;
      await _readOnce();
    });
    return cleared && _refusal == null;
  }

  /// Starts a listed task: Start decides by its state, and what it did is said.
  Future<void> startAgain(Task task) async {
    final file = projectNameOf(task);
    if (file == null || task.task.isEmpty) return;
    final repository = projectOf(task)?.repositoryOf(task);
    await _acting(about: task.name, () async {
      _say(
        startWords(
          task.name,
          await backend.startAgain(project: file, task: task.task, repository: repository),
          afterARestart: task.takenDownByARestart,
        ),
      );
      await _readOnce();
    });
  }

  /// The project [task] belongs to, or null when nothing here knows it.
  Project? projectOf(Task task) =>
      projects.where((each) => each.name == task.project).map((each) => each.project).firstOrNull;

  /// The name every call takes for the project [task] belongs to, or null when the machine does
  /// not list that project — a task left over from one it no longer has.
  String? projectNameOf(Task task) => projects
      .where((each) => each.name == task.project && each.project.file.isNotEmpty)
      .map((each) => each.project.name)
      .firstOrNull;

  /// Puts a refusal away without acting on it, leaving the task exactly as it is.
  void letItBe() {
    if (_refusal == null) return;
    _refusal = null;
    _notify();
  }

  /// Runs one action, keeping the interface honest about what happened either way.
  ///
  /// [about] keeps the outcome with that task too, for a view that shows no status line.
  Future<void> _acting(Future<void> Function() action, {String? about}) async {
    _busy = true;
    _notify();
    try {
      await action();
    } on VarlinkDisconnected catch (ex) {
      _lostContact(ex);
    } on VarlinkException catch (ex) {
      // A named refusal from the daemon is an answer. It gets said, not swallowed.
      _say('Refused: ${ex.simpleName}.');
    } on FeatureNotSupported catch (ex) {
      _say('$ex');
    } finally {
      if (about != null) _said[about] = _status;
      _busy = false;
      _notify();
    }
  }

  /// Selects a piece of work under the selected project.
  ///
  /// A name that is not there yet is allowed: a selection restored from the last run arrives
  /// before the machine has answered, and [_adopt] drops one that turns out not to exist.
  void selectTask(String? name) {
    if (_selectedTask == name) return;
    _selectedTask = name;
    _notify();
  }

  bool _readingProjects = false;

  /// Asks for the project list again, at most one at a time.
  ///
  /// `Watch` can push several changes in a row; overlapping reads would answer out of order and
  /// leave the older one on screen.
  Future<void> _readProjectsAgain() async {
    if (_readingProjects) return;
    _readingProjects = true;
    try {
      _known = await backend.projects();
      _notify();
    } on VarlinkDisconnected {
      // The watch reports a lost connection; this one staying quiet keeps one event from being
      // announced twice.
    } finally {
      _readingProjects = false;
    }
  }

  Future<void> _readOnce() async {
    try {
      // Nothing refreshes the project list on its own — `WatchProjects` is not used yet — so it is
      // asked for again beside the tasks, after anything that would have changed it.
      _known = await backend.projects();
      _adopt(await backend.tasks());
    } on VarlinkDisconnected catch (ex) {
      _lostContact(ex);
    }
  }

  void _follow() {
    _watching?.cancel();
    _watching = backend.watch().listen(
      (tasks) {
        _live = true;
        _adopt(tasks);
        // A project's counts — how much work, how much of it running, how much waiting at the
        // gate — are the daemon's, and `WatchProjects` is not used yet. `Watch` is the only signal
        // that work moved, so it is also the signal that those counts are stale. Without this the
        // work pane updated and the row above it did not.
        unawaited(_readProjectsAgain());
      },
      onError: (Object error) {
        if (error is FeatureNotSupported) {
          // Per feature, not per connection: this backend is older, so the list stops arriving
          // by itself and everything else carries on.
          _live = false;
          _say('This backend cannot push changes; refresh to see them.');
          return;
        }
        if (error is VarlinkDisconnected) {
          _lostContact(error);
          return;
        }
        _say('Watching failed: $error');
      },
    );
  }

  void _adopt(List<Task> tasks) {
    _tasks = tasks;
    // A selection that no longer exists is dropped rather than left pointing at nothing.
    final projectNames = projects.map((project) => project.name).toSet();
    if (_selectedProject != null && !projectNames.contains(_selectedProject)) {
      _selectedProject = null;
      _selectedTask = null;
    }
    if (_selectedTask != null && !tasks.any((task) => task.name == _selectedTask)) {
      _selectedTask = null;
    }
    _notify();
  }

  void _lostContact(VarlinkDisconnected ex) {
    // The last known list is kept on purpose. Clearing it would show a machine with nothing
    // running on it, which is the one reading a lost tunnel must never produce.
    _reachability = Reachability.unreachable;
    _live = false;
    _say('Lost contact with ${backend.label}: ${ex.message}');
    _tryAgainLater();
  }

  /// Tries again on its own, so a tunnel coming back does not need anybody to notice.
  ///
  /// A cut stream is resumed rather than left dead: reconnecting reads the list again and starts
  /// watching again, which is the whole of what was lost.
  void _tryAgainLater() {
    if (_disposed || retryAfter == Duration.zero) return;
    _retry?.cancel();
    _retry = Timer(retryAfter, () {
      if (_disposed) return;
      unawaited(connect());
    });
  }

  /// Says something in the status line, for an action that happened elsewhere.
  void say(String words) => _say(words);

  void _say(String status) {
    _status = status;
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _watching?.cancel();
    clearance
      ..removeListener(_notify)
      ..dispose();
    mailboxes
      ..removeListener(_notify)
      ..dispose();
    authorizations
      ..removeListener(_notify)
      ..dispose();
    super.dispose();
  }
}
