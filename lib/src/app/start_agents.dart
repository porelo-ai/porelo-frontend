import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'commands.dart' show whyNotStart;
import 'fleet_backend.dart';
import 'task_names.dart';

/// How far one repository's start has got.
enum AgentStart {
  /// Not started yet.
  waiting,

  /// Sent, and no final reply yet.
  starting,

  /// `Start`'s final reply created or brought back the task.
  started,

  /// `Start` refused it; [AgentRow.refusal] says why.
  refused,
}

/// One repository of the project, and the agent its `project.yml` names for it.
class AgentRow {
  /// A row for [repository], whose agent is [agent] (`""` where none is named).
  AgentRow({required this.repository, required this.agent, required this.goesBy});

  /// The repository the agent works in.
  final String repository;

  /// The agent named for it, by the name `Agents` reports; empty where none is named.
  final String agent;

  /// The name the machine gives that agent, verbatim.
  final String goesBy;

  /// Whether the person kept it in the start.
  bool chosen = true;

  /// Its agent's attended task in this repository, running or stopped, or null.
  Task? existing;

  /// Why it cannot be started at all, or null when it can.
  String? cannot;

  /// What to call the task: the existing one's name, or a new one made from the repository's.
  String name = '';

  /// Whether work can start for it, as the machine answers; null until asked, and from a machine too old to say.
  Readiness? readiness;

  /// Whether the machine was asked whether it can start, answered or not.
  bool asked = false;

  /// Why the machine could not say whether it can start, in words; asked again from the sign-in step.
  String? askProblem;

  /// How far its start has got.
  AgentStart state = AgentStart.waiting;

  /// Why `Start` refused it, in words.
  String? refusal;

  /// The machine's name for the agent, or the agent's own where the machine gives none.
  String get who => goesBy.isNotEmpty ? goesBy : agent;

  /// Whether its project file names an agent for it.
  bool get namesAnAgent => agent.isNotEmpty;

  /// Whether its agent runs already, and is not started again.
  bool get runs => existing?.running ?? false;

  /// Whether a stopped task is brought back rather than a new one started.
  bool get continues => existing != null && !runs;

  /// Whether it is started when the person agrees: **never once it has been**, so going back and agreeing again
  /// starts nothing twice.
  bool get toStart => chosen && startable;

  /// Whether it could be started at all, chosen or not: its agent named and installed, not running, and not
  /// started or starting from here already.
  bool get startable =>
      namesAnAgent && cannot == null && !runs && state != AgentStart.started && state != AgentStart.starting;

  /// Whether its agent has nothing to sign in with yet.
  bool get needsASignIn =>
      toStart && const <String>{'CREDENTIAL_MISSING', 'CREDENTIAL_UNUSABLE'}.contains(readiness?.outcome.name);

  /// Why the machine says it cannot start now, in its words, or null where it can or did not say.
  ///
  /// **Every answer but ready holds the start**: a locked vault or an unknown outcome never reads as ready.
  String? get held {
    final answer = readiness;
    if (!toStart || answer == null || answer.ready) return null;
    return answer.detail.isNotEmpty ? answer.detail : answer.outcome.name.toLowerCase().replaceAll('_', ' ');
  }

  /// One line on what happens to it, for the summary.
  String get plan {
    if (!namesAnAgent) return '$repository names no agent';
    if (cannot != null) return '$who in $repository is not started: $cannot';
    if (runs) return '$who runs already, as ${existing!.task}';
    if (!chosen) return '$repository is left out';
    if (state == AgentStart.started) return continues ? '$who continued $name' : '$who started as $name';
    return continues ? '$who continues $name' : '$who starts as $name in $repository';
  }
}

/// Starting an attended task for each of a project's repositories that names an agent, with that agent.
///
/// The long-running agents of their repositories, each with its session: every task is `AGENT`, with
/// no prompt. One that runs is left alone, a stopped one is brought back, and a refusal is that row's
/// answer alone.
class StartAgents extends ChangeNotifier {
  /// The project its agents are started in, or null while nothing is open.
  Project? project;

  /// One row per repository work starts in, in the project's order.
  List<AgentRow> rows = const <AgentRow>[];

  /// The agents installed on the machine.
  List<Agent> agents = const <Agent>[];

  /// Whether the machine is being read.
  bool busy = false;

  /// Why the machine could not say which agents and tasks it has, in words.
  String? problem;

  /// Why the machine could not say whether a row to start can start: the first such row's words.
  String? get askProblem => toStart.map((each) => each.askProblem).nonNulls.firstOrNull;

  FleetBackend? _machine;

  /// Counts the openings, so an answer about an earlier one never lands in a later one.
  int _opened = 0;

  /// Why the agents of [project] cannot be started at one click, or null when they can.
  ///
  /// **Absent is not "none"**: a machine older than a repository's agent says nothing about it, and
  /// the command is not offered empty.
  static String? whyNot(Project? project) {
    if (project == null) return 'no project is selected';
    if (!project.canBeActedOn) return '${project.name} is not a project this machine follows';
    final repositories = _repositoriesOf(project);
    if (repositories.isEmpty || repositories.any((each) => each.agent == null)) {
      return 'this machine does not say which agent a repository names; it needs a newer Porelo';
    }
    if (repositories.every((each) => each.agent!.isEmpty)) {
      return 'no repository of ${project.name} names an agent in its project.yml';
    }
    return null;
  }

  static List<Repository> _repositoriesOf(Project project) => <Repository>[
    for (final name in project.workRepositories)
      project.repositoryStates.where((each) => each.name == name).firstOrNull ?? Repository(name: name),
  ];

  /// The rows that are started when the person agrees.
  Iterable<AgentRow> get toStart => rows.where((each) => each.toStart);

  /// Each agent with nothing to sign in with yet, once, as the machine lists it; a row whose agent it
  /// does not list is not started at all.
  List<Agent> get signInsNeeded {
    final names = <String>{
      for (final row in rows)
        if (row.needsASignIn) row.agent,
    };
    return agents.where((each) => names.contains(each.name)).toList();
  }

  /// Whether every row to start has been answered in the latest round of asking.
  bool get asked => !busy && _asking == 0 && toStart.every((each) => each.asked);

  /// How many rounds of asking are still out.
  int _asking = 0;

  /// Counts the rounds of asking, so an answer from an earlier round never lands in a later one.
  int _round = 0;

  /// The rows the machine says cannot start now for another reason than a sign-in, with its words.
  Iterable<AgentRow> get held => rows.where((each) => each.held != null && !each.needsASignIn);

  /// Whether a start is under way.
  bool get starting => rows.any((each) => each.state == AgentStart.starting);

  /// Whether every row that was to start has its final answer.
  bool get answered =>
      rows.where((each) => each.state != AgentStart.waiting).isNotEmpty &&
      rows.every((each) => each.state != AgentStart.starting) &&
      !_running;

  bool _running = false;

  /// Opens it on [project]: reads the agents and tasks of the machine, and asks for each row whether it can start.
  Future<void> open(FleetBackend backend, Project project) async {
    final opening = ++_opened;
    _machine = backend;
    this.project = project;
    problem = null;
    busy = true;
    _running = false;
    // A round of an opening before never ends this one's: it cannot count itself down once this one began.
    _asking = 0;
    // Nothing is judged before the machine has answered: no row exists until it has.
    rows = const <AgentRow>[];
    agents = const <Agent>[];
    notifyListeners();
    try {
      final listed = await backend.agentsOn();
      final tasks = await backend.tasks();
      if (opening != _opened) return;
      agents = listed.agents;
      rows = <AgentRow>[
        for (final each in _repositoriesOf(project))
          AgentRow(repository: each.name, agent: each.agent ?? '', goesBy: each.goesBy),
      ];
      _match(project, tasks);
      await _askAll(backend, opening);
    } on VarlinkDisconnected catch (lost) {
      if (opening == _opened) problem = 'Lost contact with the machine: ${lost.message}';
    } on VarlinkException catch (refusal) {
      if (opening == _opened) {
        problem = 'The machine could not say which agents and tasks it has (${refusal.simpleName}).';
      }
    } on Exception catch (failed) {
      // An older machine without `Agents`, among others: said, never let escape an opening nobody awaits.
      if (opening == _opened) problem = 'The machine could not say which agents and tasks it has: $failed';
    } finally {
      if (opening == _opened) {
        busy = false;
        notifyListeners();
      }
    }
  }

  /// Finds each row's attended task and names the new ones, never twice and never a taken name.
  void _match(Project project, List<Task> tasks) {
    final ofTheProject = tasks.where((each) => each.project == project.name).toList();
    final taken = <String>{
      for (final task in ofTheProject)
        if (task.task.isNotEmpty) task.task,
    };
    for (final row in rows) {
      if (!row.namesAnAgent) continue;
      final its = ofTheProject
          .where(
            (each) =>
                project.repositoryOf(each) == row.repository && each.agent == row.agent && each.mode == Mode.agent,
          )
          .toList();
      row.existing =
          its.where((each) => each.running).firstOrNull ??
          its.where((each) => each.task.isNotEmpty && whyNotStart(each) == null).firstOrNull ??
          its.firstOrNull;
      if (!agents.any((each) => each.name == row.agent)) {
        row.cannot = '${row.agent} is not installed on this machine';
        continue;
      }
      final existing = row.existing;
      if (existing != null) {
        row.name = existing.task;
        if (!existing.running) {
          row.cannot = existing.task.isEmpty
              ? 'the machine does not say its name within the project'
              : whyNotStart(existing);
        }
        continue;
      }
      row.name = suggestedTaskName(row.repository, taken);
      taken.add(row.name);
      row.cannot = taskNameProblem(row.name, project: project.name);
    }
  }

  /// Leaves [repository] out of the start, or takes it in again.
  void choose(String repository, {required bool chosen}) {
    final row = rows.where((each) => each.repository == repository).firstOrNull;
    if (row == null || _running) return;
    row.chosen = chosen;
    notifyListeners();
    final machine = _machine;
    if (chosen && machine != null && !row.asked && _asking == 0) unawaited(_ask(machine, row, _opened, _round));
  }

  /// Asks the machine again whether each row can start — after somebody signed in or opened the vault.
  ///
  /// **Every row that could start, chosen or not**, and none counts as asked until it is answered again: an
  /// answer from before is never taken for one now.
  Future<void> askAgain() async {
    final machine = _machine;
    if (machine == null) return;
    await _askAll(machine, _opened);
  }

  /// One round of asking about every row that could start, the earlier answers dropped first.
  Future<void> _askAll(FleetBackend backend, int opening) async {
    final round = ++_round;
    final asking = rows.where((each) => each.startable).toList();
    for (final row in asking) {
      row
        ..asked = false
        ..readiness = null
        ..askProblem = null;
    }
    _asking++;
    notifyListeners();
    try {
      for (final row in asking) {
        if (opening != _opened || round != _round) return;
        await _ask(backend, row, opening, round);
      }
    } finally {
      if (opening == _opened) {
        _asking--;
        notifyListeners();
      }
    }
  }

  /// Asks about [row] in [round] of the opening [opening]; an answer for an opening since closed, or for a round
  /// since begun anew, lands nowhere.
  Future<void> _ask(FleetBackend backend, AgentRow row, int opening, int round) async {
    final where = project;
    bool current() => opening == _opened && round == _round;
    if (where == null || !current()) return;
    try {
      final answer = await backend.canStart(
        project: where.name,
        agent: row.agent,
        task: row.continues ? null : row.name,
        repository: row.repository,
      );
      if (current()) row.readiness = answer.naming(row.agent);
    } on FeatureNotSupported {
      // A machine older than `CanStart`: nothing is claimed either way, and `Start` answers.
    } on VarlinkDisconnected catch (lost) {
      if (current()) row.askProblem = 'Lost contact with the machine: ${lost.message}';
    } on VarlinkException catch (refusal) {
      if (current()) row.askProblem = _couldNotSay(refusal);
    } on Exception catch (failed) {
      if (current()) row.askProblem = 'The machine could not say whether work can start: $failed';
    }
    if (!current()) return;
    row.asked = true;
    notifyListeners();
  }

  /// Starts every row to start, one after another, each answered once its task exists.
  ///
  /// **Nothing reads as started before `Start`'s final reply**, a refusal stays that row's answer while the
  /// next one is started, and **nothing more is sent once the wizard is closed**.
  Future<void> startAll() async {
    final machine = _machine;
    final where = project;
    if (machine == null || where == null || _running) return;
    // Never past a hold: the wizard does not offer this then, and nothing else may start around it.
    if (!asked || askProblem != null || signInsNeeded.isNotEmpty || held.isNotEmpty) return;
    final opening = _opened;
    _running = true;
    notifyListeners();
    try {
      for (final row in toStart.toList()) {
        if (opening != _opened) return;
        row
          ..state = AgentStart.starting
          ..refusal = null;
        notifyListeners();
        String? lastLine;
        try {
          await for (final event in machine.startTask(
            task: row.name,
            project: where.name,
            agent: row.agent,
            mode: Mode.agent,
            repository: row.repository,
            now: true,
          )) {
            if (event is StartLine && event.line.trim().isNotEmpty) lastLine = event.line;
          }
          row.state = AgentStart.started;
        } on Exception catch (refused) {
          row
            ..state = AgentStart.refused
            ..refusal = _words(refused, lastLine);
        }
        if (opening == _opened) notifyListeners();
      }
    } finally {
      if (opening == _opened) {
        _running = false;
        notifyListeners();
      }
    }
  }

  static String _couldNotSay(VarlinkException refusal) {
    final said = refusal.parameters['message'] ?? refusal.parameters['detail'];
    return said is String && said.isNotEmpty
        ? 'The machine could not say whether work can start: $said'
        : 'The machine could not say whether work can start (${refusal.simpleName}).';
  }

  static String _words(Exception refused, String? lastLine) {
    final said = switch (refused) {
      VarlinkException(:final parameters) when parameters['message'] is String => parameters['message'] as String,
      _ => '$refused',
    };
    // The final reply carries only a code; what was printed before it is why.
    return refused is OperationFailed && lastLine != null ? '$said $lastLine' : said;
  }

  /// Closes it.
  void close() {
    _opened++;
    _running = false;
    busy = false;
    problem = null;
    _asking = 0;
    project = null;
    rows = const <AgentRow>[];
    agents = const <Agent>[];
    _machine = null;
    notifyListeners();
  }
}
