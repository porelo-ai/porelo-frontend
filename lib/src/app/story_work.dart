import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'planning_board.dart';
import 'fleet_backend.dart';

/// The daemon's refusal words, shared by story and reading actions.
String planningFailureWords(Object error) {
  if (error is VarlinkException) {
    for (final key in ['detail', 'message']) {
      final words = error.parameters[key];
      if (words is String && words.trim().isNotEmpty) return words;
    }
    return 'Refused: ${error.simpleName}.';
  }
  return '$error';
}

/// A proposal and start bound to one watched machine and board revision.
class StoryWork extends ChangeNotifier {
  /// Captures the initial source and the watched alternatives for the same project.
  StoryWork(
    this.board,
    this.story,
    this.to, {
    Map<PlanningBoard, String>? machines,
    this.unavailableMachines = const [],
  }) : backend = board.backend,
       project = board.project,
       revision = board.snapshot?.revision ?? '',
       machines = machines ?? {board: board.backend.label} {
    _stopFollowing = board.follow(_changed);
  }

  /// The currently chosen machine's board.
  PlanningBoard board;

  /// The story being started, as reported by this source.
  PlanStory story;

  /// The selected working state.
  String to;

  /// Watched providers of this project, labeled by their machine identities.
  final Map<PlanningBoard, String> machines;

  /// Watched machines that have not supplied this project's planning.
  final List<String> unavailableMachines;

  /// The project name sent to the chosen machine.
  String project;

  /// The opaque board revision used by this proposal.
  String revision;

  /// The chosen machine's backend.
  FleetBackend backend;

  /// The daemon's proposal, once supplied.
  StoryWorkProposal? proposal;

  /// The explicitly selected involvement mode.
  String? mode;

  /// The explanation for any changed or dropped participant.
  String comment = '';

  /// The overall reading limit retained as text for validation.
  String rounds = '';

  /// Explicit per-issue reading limits.
  final Map<String, String> issueRounds = {};

  /// The main agent and model selected per repository.
  final Map<String, StoryWorkMainAgent> repositories = {};

  /// The explicit choice for every proposed sub-agent.
  final Map<(String, String), StoryWorkChoice> choices = {};

  /// Installed agents reported by the chosen machine.
  List<Agent> agents = [];

  /// The current refusal or incomplete-answer explanation.
  String? problem;

  /// Whether the proposal or start is awaiting its answer.
  bool busy = false;

  /// Whether a submitted start has not answered yet; its machine cannot change.
  bool starting = false;

  /// The tasks returned by the successful start itself.
  StoryWorkStarted? result;
  bool _disposed = false;
  int _generation = 0;
  late VoidCallback _stopFollowing;

  /// Attaches a view while this form exists, with disposal-safe cancellation.
  VoidCallback follow(VoidCallback listener) {
    if (_disposed) return () {};
    addListener(listener);
    return () {
      if (!_disposed) removeListener(listener);
    };
  }

  /// Whether the form can still use its captured board revision.
  bool get sourceCurrent =>
      !_disposed &&
      !board.isDisposed &&
      revision.isNotEmpty &&
      identical(board.backend, backend) &&
      board.project == project &&
      board.live &&
      board.snapshot?.complete == true &&
      board.snapshot?.revision == revision;

  /// Whether the selected story and target exist on the captured source.
  bool get current =>
      sourceCurrent && board.stories.any((each) => each.id == story.id) && board.state(to)?.kind == 'WORKING';

  /// Whether a sub-agent was dropped or selected for a change.
  bool get needsComment => choices.values.any((each) => each.choice != 'KEEP');

  bool get _validSubAgents => proposal!.repositories.every(
    (repo) => repo.subAgents.every((sub) {
      final chosen = choices[(repo.repository, sub.name)];
      return switch (chosen?.choice) {
        'KEEP' => sub.agent.isNotEmpty && sub.model.isNotEmpty,
        'DROP' => true,
        'CHANGE' =>
          chosen!.agent?.isNotEmpty == true &&
              chosen.model?.isNotEmpty == true &&
              (chosen.agent != sub.agent || chosen.model != sub.model),
        _ => false,
      };
    }),
  );

  static int? _rounds(String text) {
    final value = int.tryParse(text);
    return value != null && value >= 1 ? value : null;
  }

  /// Whether every required choice and source fact permits a start.
  bool get canStart =>
      current &&
      !busy &&
      problem == null &&
      result?.started != true &&
      proposal != null &&
      proposal!.repositories.isNotEmpty &&
      board.startUnavailable(story) == null &&
      proposal!.modes.contains(mode) &&
      ['UNATTENDED', 'AGENT'].contains(mode) &&
      repositories.length == proposal!.repositories.length &&
      repositories.values.every((repo) => repo.agent.isNotEmpty && repo.model.isNotEmpty) &&
      (!needsComment || comment.trim().isNotEmpty) &&
      _rounds(rounds) != null &&
      issueRounds.values.every((value) => value.isEmpty || _rounds(value) != null) &&
      _validSubAgents;

  /// The daemon's action-specific label, or a count from its proposed tasks.
  String get startLabel => proposal == null
      ? 'Start work'
      : proposal!.startLabel.isNotEmpty
      ? proposal!.startLabel
      : 'Start ${proposal!.repositories.length} ${proposal!.repositories.length == 1 ? 'task' : 'tasks'}';

  /// Reads the proposal and agent list from the same captured machine.
  Future<void> load() async {
    if (_disposed || starting) return;
    if (!current) {
      problem = !board.stories.any((each) => each.id == story.id)
          ? 'The selected machine did not report story ${story.id}.'
          : 'The selected machine did not report a current working state for this story.';
      _changed();
      return;
    }
    final generation = ++_generation;
    final source = backend;
    final name = project;
    final id = story.id;
    final target = to;
    bool valid() => !_disposed && generation == _generation;
    busy = true;
    problem = null;
    result = null;
    proposal = null;
    repositories.clear();
    choices.clear();
    issueRounds.clear();
    agents = [];
    _changed();
    try {
      final answer = await source.proposeStoryWork(name, id, target);
      if (!valid()) return;
      proposal = answer;
      mode = answer.modes.where((each) => ['UNATTENDED', 'AGENT'].contains(each)).firstOrNull;
      rounds = answer.readingRounds?.toString() ?? '';
      for (final repo in answer.repositories) {
        repositories[repo.repository] = StoryWorkMainAgent(
          repository: repo.repository,
          agent: repo.agent,
          model: repo.model,
        );
        for (final sub in repo.subAgents) {
          choices[(repo.repository, sub.name)] = StoryWorkChoice(
            repository: repo.repository,
            name: sub.name,
            choice: 'KEEP',
          );
        }
      }
      final listed = await source.agentsOn();
      if (!valid()) return;
      agents = listed.agents;
      if (listed.failures.isNotEmpty) {
        problem = listed.failures.entries.map((each) => '${each.key}: ${each.value}').join('\n');
      }
    } catch (error) {
      if (valid()) problem = planningFailureWords(error);
    } finally {
      if (valid()) {
        busy = false;
        _changed();
      }
    }
  }

  /// Changes the machine and re-asks its own proposal at its own revision.
  void changeMachine(PlanningBoard next) {
    if (_disposed || starting || result != null || !machines.containsKey(next) || next.isDisposed) return;
    final id = story.id;
    _generation++;
    _stopFollowing();
    board = next;
    backend = next.backend;
    project = next.project;
    revision = next.snapshot?.revision ?? '';
    final reported = next.stories.where((each) => each.id == id).firstOrNull;
    story = reported ?? PlanStory.from({'id': id});
    _stopFollowing = next.follow(_changed);
    final working = next.states.where((state) => state.kind == 'WORKING');
    if (!working.any((state) => state.name == to) && working.isNotEmpty) to = working.first.name;
    proposal = null;
    repositories.clear();
    choices.clear();
    issueRounds.clear();
    agents = [];
    mode = null;
    busy = false;
    if (reported == null) {
      problem = 'The selected machine did not report story $id.';
      _changed();
    } else if (working.isEmpty) {
      problem = 'No working state was reported by the selected machine.';
      _changed();
    } else {
      unawaited(load());
    }
  }

  /// Asks a fresh proposal for another working state on this machine.
  void changeTarget(String target) {
    if (busy ||
        !sourceCurrent ||
        !board.stories.any((each) => each.id == story.id) ||
        board.state(target)?.kind != 'WORKING') {
      return;
    }
    to = target;
    unawaited(load());
  }

  /// Selects a repository's main agent or model.
  void chooseMain(String repository, {String? agent, String? model}) {
    if (!current || busy) return;
    final previous = repositories[repository];
    if (previous == null) return;
    repositories[repository] = StoryWorkMainAgent(
      repository: repository,
      agent: agent ?? previous.agent,
      model: model ?? previous.model,
    );
    _changed();
  }

  /// Chooses one of the known modes offered by the proposal.
  void chooseMode(String value) {
    if (current && !busy) {
      mode = value;
      _changed();
    }
  }

  /// Retains the person's explanation as typed.
  void setComment(String value) {
    if (current && !busy) {
      comment = value;
      _changed();
    }
  }

  /// Retains the overall or per-issue reading limit.
  void setRounds(String value, [String? issue]) {
    if (!current || busy) return;
    if (issue == null) {
      rounds = value;
    } else {
      issueRounds[issue] = value;
    }
    _changed();
  }

  /// Selects Keep, Change or Drop; Change requires an explicitly chosen model.
  void choose(String repository, StoryWorkSubAgent sub, String choice, {String? agent, String? model}) {
    if (busy || !current) return;
    final previous = choices[(repository, sub.name)];
    choices[(repository, sub.name)] = StoryWorkChoice(
      repository: repository,
      name: sub.name,
      choice: choice,
      agent: choice == 'CHANGE' ? agent ?? previous?.agent ?? sub.agent : null,
      model: choice == 'CHANGE' ? model ?? (previous?.choice == 'CHANGE' ? previous?.model : null) ?? sub.model : null,
    );
    _changed();
  }

  /// Sends all choices once and keeps the actual started tasks for terminal opening.
  Future<bool> start() async {
    if (!canStart) return false;
    final generation = _generation;
    busy = true;
    starting = true;
    _changed();
    try {
      final answer = await backend.startStoryWork(
        StoryWorkRequest(
          project: project,
          story: story.id,
          to: to,
          mode: mode!,
          revision: revision,
          subAgents: choices.values.toList(),
          repositories: repositories.values.toList(),
          comment: comment.isEmpty ? null : comment,
          readingRounds: _rounds(rounds),
          issueReadingRounds: {
            for (final each in issueRounds.entries)
              if (each.value.isNotEmpty) each.key: _rounds(each.value)!,
          },
        ),
      );
      if (_disposed || generation != _generation) return false;
      result = answer;
      if (!answer.started) problem = 'The machine did not start the story work.';
      return answer.started;
    } catch (error) {
      if (!_disposed && generation == _generation) problem = planningFailureWords(error);
      return false;
    } finally {
      if (!_disposed && generation == _generation) {
        starting = false;
        busy = false;
        _changed();
      }
    }
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _stopFollowing();
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

/// The last source facts for a story outcome or a stopped reading.
class PlanningAttention {
  /// Keeps the source facts and choices for this view or decision.
  PlanningAttention(this.board, this.story, {this.issue, this.ended})
    : project = board.project,
      source = board.backend,
      revision = board.snapshot?.revision ?? '';

  /// The project identity when these facts were observed.
  final String project;

  /// The provider that supplied these facts.
  final FleetBackend source;

  /// The revision that supplied this row and its reading round.
  final String revision;

  /// The board whose source and revision this decision uses.
  final PlanningBoard board;

  /// The story reported by that board.
  final PlanStory story;

  /// The issue whose reading stopped, when this row is a reading decision.
  final PlanIssue? issue;

  /// The machine’s reported reason and instant for an ended story run.
  final StoryWorkEnded? ended;
}

/// Findings and a revision-bound reading decision. A success waits for the board's echo.
class ReadingDecision extends ChangeNotifier {
  /// Keeps the source facts and choices for this view or decision.
  ReadingDecision(this.row) : revision = row.revision, backend = row.source, project = row.project {
    _stopFollowing = row.board.follow(_changed);
  }

  /// The source facts retained by this attention row.
  final PlanningAttention row;

  /// The opaque revision used to bind this decision.
  final String revision;

  /// The machine receiving this decision.
  final FleetBackend backend;

  /// The project name sent to the machine.
  final String project;

  /// The last findings returned by GetIssue.
  PlanningIssueDetail? detail;

  /// The daemon’s refusal or an incomplete-answer explanation.
  String? problem;

  /// Whether a request is awaiting its answer.
  bool busy = false;

  /// Whether a decision was accepted and is awaiting the board’s echo.
  bool submitted = false;
  bool _disposed = false;
  late final VoidCallback _stopFollowing;

  /// Whether this decision still belongs to a live board at its original revision.
  bool get current =>
      !_disposed &&
      !row.board.isDisposed &&
      revision.isNotEmpty &&
      identical(row.board.backend, backend) &&
      row.board.project == project &&
      row.board.live &&
      row.board.snapshot?.complete == true &&
      row.board.snapshot?.revision == revision &&
      row.board.stories.any(
        (story) => story.issues.any(
          (issue) => issue.id == row.issue?.id && issue.readingStopped == true && issue.rounds == row.issue?.rounds,
        ),
      );

  /// Why the decision cannot run, retained beside the disabled choices.
  String? get unavailable => row.board.isDisposed
      ? 'The planning source is no longer watched.'
      : !current
      ? 'The board changed or is no longer live.'
      : busy
      ? 'Waiting for the machine’s answer.'
      : submitted
      ? 'Waiting for the board to confirm the decision.'
      : problem ??
            (detail?.findingsReported != true
                ? 'The last findings have not been reported.'
                : row.issue?.rounds == null
                ? 'The reading round was not reported.'
                : null);

  /// Whether current findings, round and revision allow a reading decision.
  bool get canResolve =>
      current &&
      problem == null &&
      detail?.findingsReported == true &&
      !busy &&
      !submitted &&
      row.issue?.rounds != null;

  /// Reads the proposal or findings from the captured machine.
  Future<void> load() async {
    if (_disposed || busy || row.issue?.readingStopped != true) return;
    busy = true;
    problem = null;
    _changed();
    try {
      final answer = await backend.getPlanningIssue(project, row.issue!.id);
      if (!_disposed) {
        if (answer.findingsReported) {
          detail = answer;
        } else {
          detail ??= answer;
          problem = 'The machine did not report the last findings.';
        }
      }
    } catch (error) {
      if (!_disposed) problem = planningFailureWords(error);
    } finally {
      if (!_disposed) {
        busy = false;
        _changed();
      }
    }
  }

  /// Sends one explicit reading decision and waits for the board to clear the stop.
  Future<void> resolve(String choice, {String? comment}) async {
    if (_disposed ||
        !canResolve ||
        !['REVIEW_ANYWAY', 'ONE_MORE_ROUND', 'REWORK'].contains(choice) ||
        choice == 'REWORK' && (comment == null || comment.trim().isEmpty)) {
      return;
    }
    busy = true;
    problem = null;
    _changed();
    try {
      await backend.resolveIssueReading(
        project,
        row.issue!.id,
        row.issue!.rounds!,
        choice,
        revision,
        comment: comment?.trim(),
      );
      if (!_disposed) submitted = true;
    } catch (error) {
      if (!_disposed) problem = planningFailureWords(error);
    } finally {
      if (!_disposed) {
        busy = false;
        _changed();
      }
    }
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopFollowing();
    super.dispose();
  }
}
