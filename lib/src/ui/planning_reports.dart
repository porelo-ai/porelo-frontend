import 'dart:async';
import 'dart:convert';

import 'package:porelo_planning/porelo_planning.dart';

import '../app/machines.dart';
import '../app/outcome_words.dart' show removeWords;
import '../app/planner.dart' show plannerProjectOf;
import '../app/planner_ideas.dart';
import '../app/settings.dart';
import '../app/window_log.dart';
import '../client/models.dart' show AgentEnded, ResultState, Task, TaskResult;
import 'planning_embedding.dart';

/// Why the planner must refuse [machine] as a task's machine, or null where it takes it: the planner keeps the name as
/// the person sees it, 1 to 128 characters with no control character, no line break and no lone surrogate.
String? plannerMachineNameProblem(String machine) {
  final points = machine.runes.toList();
  if (points.isEmpty) return 'The machine has no name to report to the planner.';
  if (points.length > 128) return 'The machine name is longer than the 128 characters the planner keeps.';
  if (points.any((point) => point >= 0xd800 && point <= 0xdfff) ||
      RegExp(r'[\x00-\x1f\x7f-\x9f  ]').hasMatch(machine)) {
    return 'The machine name holds a control character or a line break, which the planner does not keep.';
  }
  return null;
}

/// Porelo's record of how an agent ended, as the planner takes it: every field as the machine gave it, none mapped.
PlanningTaskEnded plannedTaskEnded(AgentEnded ended) => PlanningTaskEnded(
  at: ended.at,
  finished: ended.finished,
  why: ended.error,
  answer: ended.lastAnswer,
  unpushed: ended.unpushed,
);

/// Reports each task this window started for a planner's offer: its start right after Start confirmed it, each new end
/// of its agent once, also across restarts of the window, and the planner's follow-up orders started once each.
///
/// The window reports through the provider's source rather than its planning client, because only the source's answer
/// carries the follow-up orders the window must start itself. Reports go one at a time, in the order they arose.
class WindowTaskReports {
  /// Takes where offers are kept, how a task is started, and where sources, tasks and stops are found.
  WindowTaskReports({
    required this.settings,
    required this.starts,
    required this.sourceNamed,
    required this.tasksOn,
    required this.stopOn,
    this.removeOn = _noRemoval,
    this.resultOf = _noResult,
    this.hand = handIdea,
    this.runtimeDirectory,
    this.projects,
  }) {
    starts.onConfirmed = started;
  }

  /// The watched machines' own, reporting to [client]'s providers, starting through [starts].
  factory WindowTaskReports.of(
    Machines machines,
    PlanningClient client,
    WindowTaskStarts starts, {
    String? runtimeDirectory,
  }) => WindowTaskReports(
    settings: machines.settings,
    starts: starts,
    sourceNamed: (name) => client.providers.where((provider) => provider.name == name).firstOrNull?.source,
    tasksOn: (name) => switch (machines.all.where((machine) => machine.name == name).firstOrNull) {
      final machine? => machines.of(machine).tasks,
      null => null,
    },
    stopOn: (machine, container) => machines.of(machine).stopWork(container),
    removeOn: (name, container) => removeHandedDiscussion(machines, name, container),
    resultOf: (name, container) => switch (machines.all.where((machine) => machine.name == name).firstOrNull) {
      final machine? => machines.of(machine).backend.taskResult(container),
      null => Future.error(StateError('$name is not watched.')),
    },
    runtimeDirectory: runtimeDirectory,
    projects: (project) => plannerProjectOf(machines, project),
  );

  /// Where offers are kept.
  final Settings settings;

  /// How a task is started.
  final WindowTaskStarts starts;

  /// The source of the provider of planning by that name, or null where none is reached now.
  final PlanningSource? Function(String provider) sourceNamed;

  /// The tasks the machine by that name lists now, or null where it is not watched.
  final List<Task>? Function(String machine) tasksOn;

  /// Stops a container on the machine it runs on.
  final Future<void> Function(Machine machine, String container) stopOn;

  /// Removes the ended task in a container on the machine by that name; a refusal is the machine's to say.
  final Future<void> Function(String machine, String container) removeOn;

  /// The result file the task in a container handed back on the machine by that name, with its content.
  final Future<TaskResult> Function(String machine, String container) resultOf;

  /// How an ended discussion's idea is handed to the planner.
  final HandIdea hand;

  /// Where the planner writes its address file, the account's own when null.
  final String? runtimeDirectory;

  /// The repository of each project, told a planner that was not given the project since it started.
  final PlannerProjects? projects;

  /// Told the story an ended discussion's idea was saved as.
  void Function(KeptDiscussion discussion, String story)? onIdeaHanded;

  /// Says a refused report or start where the window shows planning problems: the board of that provider's project.
  void Function(String? provider, String? project, Object error)? onProblem;

  /// Shows follow-up tasks this window started, as the screen's own starts are shown.
  Future<void> Function(
    PlanningSource source,
    String project,
    String story,
    List<(PlanningTaskOrder, PlanningTaskStarted)> tasks,
  )?
  onFollowUps;

  Future<void> _tail = Future<void>.value();
  bool _sweepWaiting = false;
  bool _olderSaid = false;

  /// Whether a planner not reached was said since the last report that went through, so it is said once, not on every
  /// change of a machine.
  bool _unreachedSaid = false;

  /// Reports refused for good in this window's life, by offer and event, so a refusal is not sent again on every change
  /// of the machine.
  final _refused = <(String, String)>{};

  /// Discussion ends whose idea could not be handed in this window's life, by offer and end, so it is not tried again
  /// on every change of the machine; the next start of the window tries once more.
  final _ideasNotHanded = <(String, String)>{};

  /// Whether a planner not reached for an idea was said since the last idea that went through.
  bool _ideaUnreachedSaid = false;

  /// The offers of tasks a stop took over: whatever report of them still waits is not sent, nor its answer followed.
  final _voided = <String>{};

  /// Completes once nothing is left to report.
  Future<void> get idle async {
    Future<void> seen;
    do {
      seen = _tail;
      await seen;
    } while (!identical(seen, _tail));
  }

  Future<T> _queued<T>(Future<T> Function() job) {
    final done = _tail.then((_) => job());
    _tail = done.then((_) {}, onError: (Object _) {});
    return done;
  }

  /// Looks again at every kept offer's task, reporting a start not yet told and an end not yet told.
  void sweep() {
    if (_sweepWaiting) return;
    _sweepWaiting = true;
    unawaited(
      _queued(() {
        _sweepWaiting = false;
        return _sweepNow();
      }),
    );
  }

  /// Reports [kept] as started, once the reports before it are sent.
  void started(PlannedOffer kept) =>
      unawaited(_queued(() => _quietly(kept, () => _deliver(kept, PlanningTaskEvent.started))));

  /// Reports a task through the offer kept for it, as the window's planning client does; refused where this window
  /// keeps no such offer for that project, task, container and machine.
  Future<void> report(
    String project,
    String task,
    PlanningTaskEvent event, {
    required String offer,
    required String container,
    required String machine,
    PlanningTaskEnded? ended,
  }) => _queued(() async {
    final kept = settings.plannedOffer(machine, container);
    if (kept == null || !kept.reportable || kept.offer != offer || kept.project != project || kept.task != task) {
      throw const PlanningRefusal('TaskEventConflict', {}, 'The offer does not identify a task this window started.');
    }
    await _deliver(kept, event, ended: ended);
  });

  /// Stops [tasks], each on the machine it was started on, and forgets their offers; reports nothing, since the
  /// planner voided them. Completes once each stop was asked.
  Future<void> stop(PlanningSource source, String project, String story, List<PlanningTaskStarted> tasks) async {
    final provider = starts.providerOf(source);
    for (final task in tasks) {
      final machine = starts.startedOn(project, task.container);
      if (machine == null) {
        final words = 'The window cannot stop ${task.container}: it does not know the machine it runs on.';
        _say(provider, project, PlanningRefusal('NoMachine', {'detail': words}, words));
        continue;
      }
      if (settings.planningOffer(machine.name, task.container) case final offer?) _voided.add(offer);
      try {
        await stopOn(machine, task.container);
      } on Object catch (error) {
        _say(provider, project, error);
      }
      await settings.forgetPlanningOffer(machine.name, task.container);
    }
  }

  Future<void> _sweepNow() async {
    await _keepFoundAgain();
    for (var kept in settings.plannedOffers) {
      if (!kept.reportable) {
        _sayOlder(kept);
        continue;
      }
      final task = tasksOn(kept.machine)?.where((each) => each.name == kept.container).firstOrNull;
      if (task == null) continue;
      // A later task took the container's name after the one started for the offer was removed: it is not that task.
      if ((kept.run, task.run) case (final run?, final listed?) when listed != run) {
        await settings.forgetEarlierPlanningOffer(kept.machine, kept.container);
        continue;
      }
      if (!kept.startedReported) {
        await _quietly(kept, () => _deliver(kept, PlanningTaskEvent.started));
        // An end that came before the start was told goes right after it.
        if (settings.plannedOffer(kept.machine, kept.container) case final told? when told.startedReported) {
          kept = told;
        } else {
          continue;
        }
      }
      if (task.agentEnded case final ended? when plannedEndKey(ended) != kept.ended) {
        await _quietly(kept, () => _deliver(kept, PlanningTaskEvent.ended, ended: plannedTaskEnded(ended)));
      }
    }
    for (final kept in settings.keptDiscussions) {
      final task = tasksOn(kept.machine)?.where((each) => each.name == kept.container).firstOrNull;
      if (task == null) continue;
      final (String, TaskResult?)? ending = switch (task) {
        // A prompt run records how its agent ended, with its result.
        Task(agentEnded: final ended?) => (plannedEndKey(ended), ended.result),
        // An attended session records no end of its agent: a stopped task with its result file is its end.
        Task(running: false, result: final result?) => ('left|${task.since}', result),
        _ => null,
      };
      if (ending case (final end, final named) when end != kept.ended && !_ideasNotHanded.contains((kept.offer, end))) {
        await _handIdea(kept, named, end);
      }
    }
  }

  /// Keeps each task Start made for an offer this window handed but never kept, found by the offer given as its key:
  /// the window ended before it heard Start's answer. Any end such a task shows is its own.
  Future<void> _keepFoundAgain() async {
    for (final pending in settings.pendingStarts) {
      if (starts.isStarting(pending.offer)) continue;
      final task = tasksOn(pending.machine)?.where((each) => each.callerKey == pending.offer).firstOrNull;
      if (task == null) continue;
      if (pending.discussion) {
        await settings.rememberDiscussion(
          machine: pending.machine,
          container: task.name,
          offer: pending.offer,
          provider: pending.provider,
          project: pending.project,
        );
      } else if (task.task.isNotEmpty) {
        await settings.rememberPlanningOffer(
          machine: pending.machine,
          container: task.name,
          offer: pending.offer,
          provider: pending.provider,
          project: pending.project,
          story: pending.story,
          task: task.task,
          run: task.run,
        );
      }
    }
  }

  /// Hands the idea [kept]'s discussion wrote to the planner, once for its [end]: an idea handed in, refused for its
  /// faults or never written is not handed again, also across restarts; the result file stays in the task either way.
  Future<void> _handIdea(KeptDiscussion kept, TaskResult? named, String end) async {
    if (named == null) return _noIdea(kept, end, 'it was asked for no result file');
    if (named.state != ResultState.handed) {
      return _noIdea(kept, end, switch (named.state) {
        ResultState.missing => 'it wrote no ${named.name}',
        ResultState.tooLarge => '${named.name} is larger than the machine takes',
        ResultState.unreadable => '${named.name} could not be read as text',
        _ => '${named.name} was not handed back',
      });
    }
    final TaskResult result;
    try {
      result = await resultOf(kept.machine, kept.container);
    } on Object catch (error) {
      _ideasNotHanded.add((kept.offer, end));
      return _sayIdea(
        kept,
        'The idea of the discussion ${kept.container} could not be read from ${kept.machine}: $error',
      );
    }
    final content = result.content;
    if (result.state != ResultState.handed || content == null) {
      return _noIdea(kept, end, '${result.name} was not handed back');
    }
    if (utf8.encode(content).length > mostIdeaBytes) {
      return _noIdea(kept, end, '${result.name} is larger than the planner takes (64 KiB)');
    }
    final Object? idea;
    try {
      idea = jsonDecode(content);
    } on FormatException {
      return _noIdea(kept, end, '${result.name} holds no JSON');
    }
    if (idea is! Map<String, Object?>) return _noIdea(kept, end, '${result.name} holds no JSON object');
    final String story;
    try {
      story = await hand(kept.project, kept.offer, idea, runtimeDirectory: runtimeDirectory, projects: projects);
    } on IdeaNotSaved catch (refusal) {
      if (refusal.transient) {
        if (_ideaUnreachedSaid) return;
        _ideaUnreachedSaid = true;
        return _sayIdea(kept, 'The idea of the discussion ${kept.container} is not handed in yet: ${refusal.words}');
      }
      if (refusal.faults.isNotEmpty) {
        await settings.discussionHanded(kept.machine, kept.container, end);
      } else {
        _ideasNotHanded.add((kept.offer, end));
      }
      return _sayIdea(kept, _refusedIdea(kept, refusal));
    }
    _ideaUnreachedSaid = false;
    await settings.discussionHanded(kept.machine, kept.container, end);
    if (onIdeaHanded case final told?) {
      told(kept, story);
    } else {
      windowLog.info('Planning: the idea of the discussion ${kept.container} was saved as $story in ${kept.project}.');
    }
    // Its idea is the planner's now, so the ended discussion goes, as a person would remove it; one whose idea was not
    // saved stays with its result file.
    try {
      await removeOn(kept.machine, kept.container);
    } on Object catch (error) {
      _sayIdea(kept, 'The discussion ${kept.container} was handed in as $story, but could not be removed: $error');
    }
  }

  /// Says that [kept]'s discussion left no idea to hand in at [end], once.
  Future<void> _noIdea(KeptDiscussion kept, String end, String why) async {
    await settings.discussionHanded(kept.machine, kept.container, end);
    _sayIdea(kept, 'The discussion ${kept.container} ended with no idea to hand to the planner: $why.');
  }

  static String _refusedIdea(KeptDiscussion kept, IdeaNotSaved refusal) {
    final faults = [for (final fault in refusal.faults) fault.endsWith('.') ? ' $fault' : ' $fault.'].join();
    return 'The planner did not save the idea of the discussion ${kept.container}: ${refusal.words}$faults '
        'Its result file stays in the task.';
  }

  void _sayIdea(KeptDiscussion kept, String words) =>
      _say(kept.provider, kept.project, PlanningRefusal('IdeaNotHanded', {'detail': words}, words));

  /// Sends one report and starts what its answer orders; a refusal that will not change by itself is not sent again in
  /// this window's life. A report told meanwhile, of the same offer, is not sent again.
  Future<void> _deliver(PlannedOffer asked, PlanningTaskEvent event, {PlanningTaskEnded? ended}) async {
    final kept = settings.plannedOffer(asked.machine, asked.container);
    if (kept == null || kept.offer != asked.offer || !kept.reportable) return;
    final project = kept.project!, task = kept.task!, provider = kept.provider!;
    final endKey = ended == null ? null : _endKey(ended);
    if (event == PlanningTaskEvent.started && kept.startedReported || endKey != null && endKey == kept.ended) return;
    final attempt = (kept.offer, endKey ?? event.name);
    if (_voided.contains(kept.offer) || _refused.contains(attempt)) return;
    if (plannerMachineNameProblem(kept.machine) case final words?) {
      _refused.add(attempt);
      throw PlanningRefusal('InvalidSettings', {'detail': words}, words);
    }
    final source = sourceNamed(provider);
    if (source == null) throw PlanningRefusal('PlannerUnreachable', const {}, '$provider is not reached now.');
    final TaskEventResolution answer;
    try {
      answer = await source.taskEvent(
        project,
        task,
        event,
        offer: kept.offer,
        container: kept.container,
        machine: kept.machine,
        ended: ended,
      );
    } on PlanningRefusal catch (refusal) {
      if (refusal.name == 'TaskNotAnswered') return _voidTask(kept);
      if (!_transient(refusal)) _refused.add(attempt);
      rethrow;
    } on Object {
      _refused.add(attempt);
      rethrow;
    }
    _unreachedSaid = false;
    // A stop took the task over while its report waited: the answer's follow-ups belong to a stopped run.
    if (_voided.contains(kept.offer)) return;
    await settings.planningOfferReported(
      kept.machine,
      kept.container,
      started: event == PlanningTaskEvent.started ? true : null,
      ended: endKey,
    );
    await _startFollowUps(source, provider, project, kept.story!, answer.tasks, kept.offer);
  }

  /// The planner voided the task's offer: the task stops, its offer goes, and nothing of it is reported again.
  Future<void> _voidTask(PlannedOffer kept) async {
    _voided.add(kept.offer);
    if (starts.machineNamed(kept.machine) case final machine?) {
      try {
        await stopOn(machine, kept.container);
      } on Object catch (error) {
        _say(kept.provider, kept.project, error);
      }
    }
    await settings.forgetPlanningOffer(kept.machine, kept.container);
  }

  /// Starts each follow-up order not handed to Start before, in order, until one is refused, and shows those started.
  Future<void> _startFollowUps(
    PlanningSource source,
    String provider,
    String project,
    String story,
    List<PlanningTaskOrder> orders,
    String reported,
  ) async {
    final started = <(PlanningTaskOrder, PlanningTaskStarted)>[];
    for (final order in orders) {
      if (_voided.contains(reported)) break;
      final offer = order.offer;
      if (offer == null || settings.planningOfferHanded(offer)) continue;
      try {
        started.add((order, await starts(source, project, story, order)));
      } on Object catch (error) {
        _say(provider, project, error);
        break;
      }
    }
    if (started.isEmpty) return;
    try {
      await onFollowUps?.call(source, project, story, started);
    } on Object catch (error) {
      _say(provider, project, error);
    }
  }

  Future<void> _quietly(PlannedOffer kept, Future<void> Function() report) async {
    try {
      await report();
    } on Object catch (error) {
      if (error is PlanningRefusal && _transient(error)) {
        if (_unreachedSaid) return;
        _unreachedSaid = true;
      }
      _say(kept.provider, kept.project, error);
    }
  }

  void _sayOlder(PlannedOffer kept) {
    if (_olderSaid || tasksOn(kept.machine)?.any((each) => each.name == kept.container) != true) return;
    _olderSaid = true;
    const words =
        'Tasks started for the planner by an earlier build of this window are not reported to it: that build kept '
        'no project or task name for them.';
    _say(null, null, const PlanningRefusal('NotReportable', {'detail': words}, words));
  }

  void _say(String? provider, String? project, Object error) {
    if (onProblem case final say?) {
      say(provider, project, error);
    } else {
      windowLog.warn('Planning: ${planningFailureWords(error)}');
    }
  }

  static Future<TaskResult> _noResult(String machine, String container) =>
      Future.error(StateError('$machine answers no result files here.'));

  static Future<void> _noRemoval(String machine, String container) async {}

  static String _endKey(PlanningTaskEnded ended) =>
      plannedEndKey(AgentEnded(at: ended.at, finished: ended.finished, unpushed: ended.unpushed));

  // The planner did not answer at all, or was not asked since no watched machine named the project's repository yet; a
  // later change of a machine tries again.
  static bool _transient(PlanningRefusal refusal) =>
      const {'PlannerUnreachable', 'TimedOut', 'NoAddress', 'NoRepository'}.contains(refusal.name);
}

/// Removes the handed-in discussion in [container] on the watched machine [name], as a person would. A refusal is the
/// hand-in's to say, not a question to the person, who never asked for this removal: it is put away and thrown.
Future<void> removeHandedDiscussion(Machines machines, String name, String container) async {
  final machine = machines.all.where((machine) => machine.name == name).firstOrNull;
  if (machine == null) return;
  final fleet = machines.of(machine);
  await fleet.removeWork(container);
  if (fleet.refusal case final refused? when refused.task == container) {
    fleet.letItBe();
    throw StateError(removeWords(container, refused.result));
  }
}
