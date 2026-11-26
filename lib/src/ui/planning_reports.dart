import 'dart:async';
import 'dart:convert';

import 'package:porelo_planning/porelo_planning.dart';

import '../app/machines.dart';
import '../app/planner.dart' show plannerProjectOf;
import '../app/planner_stage_results.dart';
import '../app/report_at_planner.dart';
import '../app/settings.dart';
import '../app/window_log.dart';
import '../client/models.dart' show AgentEnded, ResultState, Task, TaskEnd, TaskResult;
import 'planning_embedding.dart';
import '../wire/limit_factors.dart';

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
///
/// [declared] is the end the task's row shows: its outcome goes with the record, and its why, the task's reason or
/// the run's error, stands for the agent's error where it says one. [landed] is where its work landed, from the task's
/// row; none while it waits at the gate.
PlanningTaskEnded plannedTaskEnded(AgentEnded ended, {TaskEnd? declared, List<PlanningLanding> landed = const []}) =>
    PlanningTaskEnded(
      at: ended.at,
      finished: ended.finished,
      why: switch (declared?.why) {
        final why? when why.isNotEmpty => why,
        _ => ended.error,
      },
      answer: ended.lastAnswer,
      unpushed: ended.unpushed,
      landed: landed,
      outcome: switch (declared?.outcome) {
        final outcome? when outcome.isNotEmpty => outcome,
        _ => null,
      },
    );

/// Where a task's work landed, each entry of its row as Porelo gave it; an entry missing a field is passed as empty
/// there, for the planner to refuse rather than the window to judge.
List<PlanningLanding> plannedLandings(Task task) => [
  for (final entry in task.landed ?? const <Map<String, dynamic>>[])
    PlanningLanding(
      branch: entry['branch'] is String ? entry['branch'] as String : '',
      ref: entry['ref'] is String ? entry['ref'] as String : '',
      remote: entry['remote'] is String ? entry['remote'] as String : '',
      commit: entry['commit'] is String ? entry['commit'] as String : '',
    ),
];

/// Tells [source] that Porelo refused the start of [refused]'s offer, answering the orders that follow.
typedef TellRefused = Future<TaskEventResolution> Function(PlanningSource source, RefusedStart refused);

/// Tells the planner a refused start through its task event call, with no container: Start made none.
Future<TaskEventResolution> tellPlannerRefused(PlanningSource source, RefusedStart refused) => source.taskEvent(
  refused.project,
  refused.task,
  PlanningTaskEvent.refused,
  offer: refused.offer,
  container: '',
  machine: refused.machine,
  refusal: PlanningStartRefusal(name: refused.name, parameters: refused.parameters, detail: refused.detail),
);

/// Reports each task this window started for a planner's offer: its start right after Start confirmed it, each new end
/// of its agent once, also across restarts of the window, and the planner's follow-up orders started once each.
///
/// A task the planning screen's run handed to Start in this window's life is reported through that run, as the screen's
/// own client reports, so the run no longer counts its start as unreported and starts the follow-up orders itself. A
/// task the window started itself, or one kept from before this window started, is reported through the provider's
/// source, whose answer carries the follow-up orders the window then starts. Reports go one at a time, in the order
/// they arose.
class WindowTaskReports {
  /// Takes where offers are kept, how a task is started, and where sources, tasks and stops are found.
  WindowTaskReports({
    required this.settings,
    required this.starts,
    required this.sourceNamed,
    required this.tasksOn,
    required this.stopOn,
    this.resultOf = _noResult,
    this.handResult = handStageResult,
    this.runtimeDirectory,
    this.projects,
    this.missingSettles = const Duration(minutes: 1),
    this.now = DateTime.now,
    this.waitForOutcome = _aMoment,
    this.tellRefused = tellPlannerRefused,
  }) {
    starts.onConfirmed = started;
    starts.onRefused = refusedStart;
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
      final machine? => machines.watching(machine)?.tasks,
      null => null,
    },
    stopOn: (machine, container) => switch (machines.watching(machine)) {
      final fleet? => fleet.stopWork(container),
      null => Future.error(StateError('${machine.name} is not answering yet, so $container was not stopped.')),
    },
    resultOf: (name, container) => switch (machines.all.where((machine) => machine.name == name).firstOrNull) {
      final machine? => switch (machines.watching(machine)) {
        final fleet? => fleet.backend.taskResult(container),
        null => Future.error(StateError('$name is not answering yet.')),
      },
      null => Future.error(StateError('$name is not watched.')),
    },
    runtimeDirectory: runtimeDirectory,
    projects: (project) => plannerProjectOf(machines, project),
  );

  /// Where offers are kept.
  final Settings settings;

  /// How a refused start is told its planner.
  final TellRefused tellRefused;

  /// Waits while an ended run's row does not show the outcome its task declared yet; the end is told after it either
  /// way, without one where the row still shows none.
  final Future<void> Function() waitForOutcome;

  static Future<void> _aMoment() => Future<void>.delayed(const Duration(seconds: 5));

  /// How a task is started.
  final WindowTaskStarts starts;

  /// The source of the provider of planning by that name, or null where none is reached now.
  final PlanningSource? Function(String provider) sourceNamed;

  /// The tasks the machine by that name lists now, or null where it is not watched.
  final List<Task>? Function(String machine) tasksOn;

  /// Stops a container on the machine it runs on.
  final Future<void> Function(Machine machine, String container) stopOn;

  /// The result file the task in a container handed back on the machine by that name, with its content.
  final Future<TaskResult> Function(String machine, String container) resultOf;

  /// How what an ended planned stage produced is handed to the planner, before its end is reported.
  final HandStageResult handResult;

  /// Where the planner writes its address file, the account's own when null.
  final String? runtimeDirectory;

  /// The repository of each project, told a planner that was not given the project since it started.
  final PlannerProjects? projects;

  /// How long a planned stage's result file missing at its end is looked at again before it is said to be missing: a
  /// listing may show the end before the machine took the file.
  final Duration missingSettles;

  /// The time now.
  final DateTime Function() now;

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

  /// The offers handed by an earlier window whose machine's tasks were not known when an answer carried them: said once.
  final _undecidedSaid = <String>{};

  /// Reports refused for good in this window's life, by offer and event, so a refusal is not sent again on every change
  /// of the machine.
  final _refused = <(String, String)>{};

  /// When each planned stage was first seen ended with its result file missing, by offer and end, so it is looked at
  /// again until [missingSettles] passed.
  final _resultMissingSince = <(String, String), DateTime>{};

  /// Stage ends whose result could not be read from the machine yet, by offer and end, so it is said once; it is read
  /// again on later sweeps.
  final _resultsNotRead = <(String, String)>{};

  /// Whether a planner not reached for a stage's result was said since the last one that went through.
  bool _resultUnreachedSaid = false;

  /// The offers of tasks a stop took over: whatever report of them still waits is not sent, nor its answer followed.
  final _voided = <String>{};

  /// Reports through the screen's run, as the screen's own client sends them.
  final _screen = _ScreenRunReports();

  /// Ends seen while their row showed no outcome yet, by machine, container and end: false while the wait for the
  /// outcome runs, true once it is over and the end goes with whatever the row then shows.
  final _heldForOutcome = <(String, String, String), bool>{};

  /// The waits for an outcome still running, each looking at the machines again when it is over.
  final _waits = <Future<void>>{};

  /// Whether the end [held] still waits for its outcome; its wait starts the first time it is seen.
  bool _stillHeld((String, String, String) held) {
    if (_heldForOutcome[held] case final over?) return !over;
    _heldForOutcome[held] = false;
    // A wait that fails is over all the same: the end is told without its outcome rather than never.
    late final Future<void> wait;
    wait = waitForOutcome().catchError((Object _) {}).whenComplete(() {
      _heldForOutcome[held] = true;
      _waits.remove(wait);
      sweep();
    });
    _waits.add(wait);
    return true;
  }

  /// Completes once nothing is left to report.
  Future<void> get idle async {
    Future<void> seen;
    do {
      while (_waits.isNotEmpty) {
        await Future.wait(_waits.toList());
      }
      seen = _tail;
      await seen;
    } while (!identical(seen, _tail) || _waits.isNotEmpty);
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

  /// Reports that Porelo refused [refused]'s start, once the reports before it are sent.
  void refusedStart(RefusedStart refused) => unawaited(_queued(() => _tellRefusedQuietly(refused)));

  /// Reports each refused start kept and not taken by its planner yet; one the planner refused for good is not sent
  /// again in this window's life.
  Future<void> _tellRefusedStarts() async {
    for (final refused in settings.refusedStarts) {
      await _tellRefusedQuietly(refused);
    }
  }

  /// Tells [refused] as [_tellRefused] does; one that cannot be told or forgotten is said, and never holds back the
  /// other reports.
  Future<void> _tellRefusedQuietly(RefusedStart refused) async {
    try {
      await _tellRefused(refused);
    } on Object catch (error) {
      _say(refused.provider, refused.project, error);
    }
  }

  /// Tells [refused]'s planner that Porelo refused its offer's start, once: kept until the planner took it, or holds
  /// nothing of the offer, and sent again on a later sweep where the planner was not reached.
  Future<void> _tellRefused(RefusedStart refused) async {
    final attempt = (refused.offer, 'refused');
    if (_refused.contains(attempt)) return;
    if (!settings.refusedStarts.any((each) => each.offer == refused.offer)) return;
    final source = sourceNamed(refused.provider);
    if (source == null) {
      if (!_unreachedSaid) {
        _unreachedSaid = true;
        _say(
          refused.provider,
          refused.project,
          PlanningRefusal('PlannerUnreachable', const {}, '${refused.provider} is not reached now.'),
        );
      }
      return;
    }
    if (await starts.screenRunOf(refused.offer) case final run?) {
      // As for any report: only the very source whose run handed the offer to Start, and one that tells what came of
      // it at its planner, is reported through.
      if (identical(run, source) && source is TellsTaskReports && await _refusedThroughTheScreen(refused, source)) {
        return;
      }
      starts.notFromTheScreen(refused.offer);
    }
    final TaskEventResolution answer;
    try {
      answer = await tellRefused(source, refused);
    } on Object catch (error) {
      return _refusalNotTaken(refused, error);
    }
    _unreachedSaid = false;
    if (await _startFollowUps(source, refused.provider, refused.project, refused.story, answer.tasks, refused.offer)) {
      await settings.forgetRefusedStart(refused.offer);
    }
  }

  /// Sends [refused]'s report through the screen's run that handed its offer to Start, which starts the answer's
  /// follow-up orders itself. Answers false where that run holds no refused Start of the offer, so the report goes to
  /// the source as for a start the window asked for itself.
  Future<bool> _refusedThroughTheScreen(RefusedStart refused, PlanningSource source) async {
    final at = ReportAtPlanner(refused.offer);
    Object? afterTheAnswer;
    _screen.providers = [
      PlanningProvider(name: refused.provider, connected: true, projects: [refused.project], source: source),
    ];
    try {
      await at.watch(
        () => _screen.taskEvent(
          refused.project,
          refused.task,
          PlanningTaskEvent.refused,
          offer: refused.offer,
          container: '',
          machine: refused.machine,
          refusal: PlanningStartRefusal(name: refused.name, parameters: refused.parameters, detail: refused.detail),
        ),
      );
    } on Object catch (error) {
      if (!at.asked && planningRefused(error, 'TaskEventConflict')) return false;
      if (!at.answered) {
        await _refusalNotTaken(refused, error);
        return true;
      }
      // The planner took the report; what the run could not start after its answer is said, and nothing is sent again.
      afterTheAnswer = error;
    }
    _unreachedSaid = false;
    await settings.forgetRefusedStart(refused.offer);
    starts.notFromTheScreen(refused.offer);
    if (afterTheAnswer != null) _say(refused.provider, refused.project, afterTheAnswer);
    return true;
  }

  /// A refused start's report the planner did not take: one for a task it no longer answers for is forgotten, one it was
  /// not reached for is said once and sent again on a later sweep, and any other is said once and not sent again.
  Future<void> _refusalNotTaken(RefusedStart refused, Object error) async {
    if (error is PlanningRefusal && error.name == 'TaskNotAnswered') {
      await settings.forgetRefusedStart(refused.offer);
      return;
    }
    if (error is PlanningRefusal && _transient(error)) {
      if (_unreachedSaid) return;
      _unreachedSaid = true;
      _say(refused.provider, refused.project, error);
      return;
    }
    _refused.add((refused.offer, 'refused'));
    _say(refused.provider, refused.project, error);
    // Refused for good: not kept for a later window to send again.
    if (error is PlanningRefusal) await settings.forgetRefusedStart(refused.offer);
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
    List<PlanningLanding> landed = const [],
  }) => _queued(() async {
    final kept = settings.plannedOffer(machine, container);
    if (kept == null || !kept.reportable || kept.offer != offer || kept.project != project || kept.task != task) {
      throw const PlanningRefusal('TaskEventConflict', {}, 'The offer does not identify a task this window started.');
    }
    await _deliver(kept, event, ended: ended, landed: landed);
  });

  /// Stops [tasks], each on the machine it was started on, forgets their offers and, once a task is stopped, reports
  /// its end through its kept offer, once: the planner holds a stopped run's task started until its end is told, and
  /// starts the story again only then. Nothing else of them is reported. Completes once each stop was asked.
  Future<void> stop(PlanningSource source, String project, String story, List<PlanningTaskStarted> tasks) async {
    final provider = starts.providerOf(source);
    for (final task in tasks) {
      final machine = starts.startedOn(project, task.container);
      if (machine == null) {
        final words = 'The window cannot stop ${task.container}: it does not know the machine it runs on.';
        _say(provider, project, PlanningRefusal('NoMachine', {'detail': words}, words));
        continue;
      }
      final kept = settings.plannedOffer(machine.name, task.container);
      if (settings.planningOffer(machine.name, task.container) case final offer?) _voided.add(offer);
      await _stopAndEnd(machine, task.container, kept, source);
    }
  }

  /// Stops [container] on [machine] where it still runs and, once it stands stopped, reports the end of [kept]'s task
  /// to [source] after the reports before it. The offer is kept until the planner took that end, so a later Stop, which
  /// names the task again, stops or ends what is still left; a task the window keeps no reportable offer for is
  /// forgotten once stopped.
  Future<void> _stopAndEnd(Machine machine, String container, PlannedOffer? kept, PlanningSource? source) async {
    final listed = tasksOn(machine.name)?.where((each) => each.name == container).firstOrNull;
    // A stop asked again of a task already stopped only tells its end.
    if (listed == null || listed.running) {
      try {
        await stopOn(machine, container);
      } on Object catch (error) {
        _say(kept?.provider ?? (source == null ? null : starts.providerOf(source)), kept?.project, error);
        return;
      }
    }
    if (kept == null || !kept.reportable || source == null) {
      await settings.forgetPlanningOffer(machine.name, container);
      return;
    }
    if (!_endsWaiting.add(kept.offer)) return;
    // Queued, so it follows a start's report still waiting for its answer: an end before its start is refused.
    unawaited(
      _queued(() async {
        try {
          await _endStopped(kept, source);
        } finally {
          _endsWaiting.remove(kept.offer);
        }
      }),
    );
  }

  /// The offers whose stopped task's end waits to be told, so it is told once.
  final _endsWaiting = <String>{};

  /// Reports that the window stopped [kept]'s task: with how its agent ended where the machine lists a new end, else
  /// now, unfinished. The answer's orders belong to a stopped run and are not started. The offer is forgotten once the
  /// planner took the end or holds nothing to end; one it could not be told keeps the offer for the next Stop.
  Future<void> _endStopped(PlannedOffer kept, PlanningSource source) async {
    final current = settings.plannedOffer(kept.machine, kept.container);
    if (current == null || current.offer != kept.offer) return;
    final listed = tasksOn(kept.machine)?.where((each) => each.name == kept.container).firstOrNull;
    final ended = switch (listed?.agentEnded) {
      final ended? when plannedEndKey(ended) != kept.ended => plannedTaskEnded(
        ended,
        declared: listed!.ended,
        landed: plannedLandings(listed),
      ),
      _ => PlanningTaskEnded(
        at: now().toUtc().toIso8601String(),
        finished: false,
        why: 'The window stopped the task.',
        answer: '',
        unpushed: 0,
      ),
    };
    try {
      await source.taskEvent(
        kept.project!,
        kept.task!,
        PlanningTaskEvent.ended,
        offer: kept.offer,
        container: kept.container,
        machine: kept.machine,
        ended: ended,
      );
    } on PlanningRefusal catch (refusal) {
      // The planner holds nothing of the task any more, or never heard it started (its start's report was dropped by
      // the stop, or never taken): there is nothing to end, and no error.
      final nothingToEnd =
          refusal.name == 'TaskNotAnswered' || refusal.name == 'TaskEventConflict' && !current.startedReported;
      if (!nothingToEnd) {
        _say(kept.provider, kept.project, refusal);
        if (_transient(refusal) || refusal.name != 'TaskEventConflict') return;
      }
    } on Object catch (error) {
      _say(kept.provider, kept.project, error);
      return;
    }
    await settings.forgetPlanningOffer(kept.machine, kept.container);
  }

  Future<void> _sweepNow() async {
    await _keepFoundAgain();
    await _tellRefusedStarts();
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
      final landed = plannedLandings(task);
      // The row may show the run's end before the outcome its task declared: told without it, it is never told again.
      if (task.agentEnded case final ended? when plannedEndKey(ended) != kept.ended && task.ended == null) {
        if (_stillHeld((kept.machine, kept.container, plannedEndKey(ended)))) continue;
      }
      if (task.agentEnded case final ended? when plannedEndKey(ended) != kept.ended) {
        // A planned stage's end is reported only once the planner has what it produced: it moves the issue on that.
        if (kept.result != null && kept.resultHanded != plannedEndKey(ended)) {
          if (!await _handStageResult(kept, plannedEndKey(ended))) continue;
          kept = settings.plannedOffer(kept.machine, kept.container) ?? kept;
        }
        await _quietly(
          kept,
          () => _deliver(
            kept,
            PlanningTaskEvent.ended,
            ended: plannedTaskEnded(ended, declared: task.ended, landed: landed),
          ),
        );
      }
      // Work that still waited at the gate when its task ended is told once it has landed, so its reader is offered.
      if (settings.plannedOffer(kept.machine, kept.container) case final told?
          when landed.isNotEmpty &&
              !told.landedReported &&
              told.ended != null &&
              task.agentEnded?.finished == true &&
              told.ended == plannedEndKey(task.agentEnded!)) {
        await _quietly(told, () => _deliver(told, PlanningTaskEvent.landed, landed: landed));
      }
    }
  }

  /// Keeps each task Start made for an offer this window handed but never kept, found by the offer given as its key:
  /// the window ended before it heard Start's answer. Any end such a task shows is its own.
  Future<void> _keepFoundAgain() async {
    for (final pending in settings.pendingStarts) {
      if (starts.isStarting(pending.offer)) continue;
      // The key alone could be another project's: a task is the offer's only in the offer's own project.
      final task = tasksOn(pending.machine)
          ?.where((each) => each.callerKey == pending.offer && each.project == pending.project)
          .firstOrNull;
      if (task == null) continue;
      if (pending.discussion) {
        // A discussion hands its idea back as a report its planner reads: nothing more is kept of it.
        await settings.forgetPendingStart(pending.offer);
      } else if (task.task.isEmpty) {
        // Kept neither as a discussion nor as a story's task, it would wait in the settings for ever.
        windowLog.warn('Planning: the task ${task.name} on ${pending.machine} names no task; its start is let go.');
        await settings.forgetPendingStart(pending.offer);
      } else {
        await settings.rememberPlanningOffer(
          machine: pending.machine,
          container: task.name,
          offer: pending.offer,
          provider: pending.provider,
          project: pending.project,
          story: pending.story,
          task: task.task,
          run: task.run,
          result: pending.result,
          role: pending.role,
          issues: pending.issues,
        );
      }
    }
  }

  /// Hands what [kept]'s planned stage produced at [end] to the planner: its result file's object, or one line of why
  /// there is none. Answers whether the planner has it now, saved or refused, so the end may be reported; a planner
  /// not reached, a result still missing so soon after the end, or one that could not be read answers false, and is
  /// tried again on a later sweep: the end waits for the result rather than go on without it.
  Future<bool> _handStageResult(PlannedOffer kept, String end) async {
    final name = kept.result!;
    final TaskResult read;
    try {
      read = await resultOf(kept.machine, kept.container);
    } on Object catch (error) {
      // Said once; read again once [missingSettles] passed, or on the next change of the machine.
      if (_resultsNotRead.add((kept.offer, end))) {
        Timer(pollEvery(missingSettles), sweep);
        _sayLogged(
          kept.provider,
          kept.project,
          'The $name of ${kept.container} could not be read from ${kept.machine} yet: $error',
        );
      }
      return false;
    }
    if (read.state == ResultState.missing) {
      // The machine takes the file at the end; a listing may show the end before it did.
      if (!_resultMissingSince.containsKey((kept.offer, end))) Timer(pollEvery(missingSettles), sweep);
      final first = _resultMissingSince.putIfAbsent((kept.offer, end), now);
      if (now().difference(first) < pollEvery(missingSettles)) return false;
    }
    _resultMissingSince.remove((kept.offer, end));
    final content = read.content;
    final Map<String, Object?>? result;
    final String? missing;
    if (read.state != ResultState.handed || content == null) {
      (result, missing) = (
        null,
        switch (read.state) {
          ResultState.missing => 'it wrote no $name',
          ResultState.tooLarge => '$name is larger than the machine takes',
          ResultState.unreadable => '$name could not be read as text',
          _ => '$name was not handed back',
        },
      );
    } else if (utf8.encode(content).length > mostStageResultBytes) {
      (result, missing) = (null, '$name is larger than the planner takes (1 MiB)');
    } else {
      Object? json;
      try {
        json = jsonDecode(content);
      } on FormatException {
        json = null;
      }
      (result, missing) = switch (json) {
        // Measured as it is sent: the object written again as JSON may be longer than the file was.
        final Map<String, Object?> object
            when utf8.encode(jsonEncode({'offer': kept.offer, 'result': object})).length > mostStageResultBody =>
          (null, '$name is larger than the planner takes (1 MiB)'),
        final Map<String, Object?> object => (object, null),
        _ => (null, '$name holds no JSON object'),
      };
    }
    try {
      await handResult(
        kept.project!,
        kept.task!,
        kept.offer,
        result: result,
        missing: missing,
        runtimeDirectory: runtimeDirectory,
        projects: projects,
      );
      _resultUnreachedSaid = false;
      if (missing != null) {
        _sayLogged(kept.provider, kept.project, 'The task ${kept.container} ended with no result: $missing.');
      }
    } on StageResultNotSaved catch (refusal) {
      if (refusal.transient) {
        if (!_resultUnreachedSaid) {
          _resultUnreachedSaid = true;
          _sayLogged(
            kept.provider,
            kept.project,
            'The $name of ${kept.container} is not handed in yet: ${refusal.words}',
          );
        }
        return false;
      }
      final faults = [for (final fault in refusal.faults) fault.endsWith('.') ? ' $fault' : ' $fault.'].join();
      _sayLogged(
        kept.provider,
        kept.project,
        'The planner did not save the $name of ${kept.container}: ${refusal.words}$faults',
      );
    }
    await settings.planningOfferReported(kept.machine, kept.container, resultHanded: end);
    return true;
  }

  /// Says what became of a stage's result where the window shows planning problems, and writes it to the window's log too, so
  /// it is still known once the board is gone.
  void _sayLogged(String? provider, String? project, String words) {
    final refusal = PlanningRefusal('ResultNotHanded', {'detail': words}, words);
    if (onProblem != null) windowLog.warn('Planning: ${planningFailureWords(refusal)}');
    _say(provider, project, refusal);
  }

  /// Sends one report and starts what its answer orders; a refusal that will not change by itself is not sent again in
  /// this window's life. A report told meanwhile, of the same offer, is not sent again.
  Future<void> _deliver(
    PlannedOffer asked,
    PlanningTaskEvent event, {
    PlanningTaskEnded? ended,
    List<PlanningLanding> landed = const [],
  }) async {
    final kept = settings.plannedOffer(asked.machine, asked.container);
    if (kept == null || kept.offer != asked.offer || !kept.reportable) return;
    final project = kept.project!, task = kept.task!, provider = kept.provider!;
    final endKey = ended == null ? null : _endKey(ended);
    if (event == PlanningTaskEvent.started && kept.startedReported || endKey != null && endKey == kept.ended) return;
    if (event == PlanningTaskEvent.landed && kept.landedReported) return;
    final attempt = (kept.offer, endKey ?? event.name);
    if (_voided.contains(kept.offer) || _refused.contains(attempt)) return;
    if (plannerMachineNameProblem(kept.machine) case final words?) {
      _refused.add(attempt);
      throw PlanningRefusal('InvalidSettings', {'detail': words}, words);
    }
    final source = sourceNamed(provider);
    if (source == null) throw PlanningRefusal('PlannerUnreachable', const {}, '$provider is not reached now.');
    if (await starts.screenRunOf(kept.offer) case final run?) {
      // A planner found again answers through another source: the run of the one gone reports nothing more. Only a
      // source that tells what came of a report at its planner is reported through, so a report is never taken for
      // sent, or sent twice, on a guess.
      if (identical(run, source) && source is TellsTaskReports) {
        if (await _throughTheScreen(kept, source, event, endKey, attempt, ended: ended, landed: landed)) return;
      }
      starts.notFromTheScreen(kept.offer);
    }
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
        landed: landed,
      );
    } on Object catch (error, stack) {
      return _notTaken(kept, error, stack, attempt, event: event, source: source);
    }
    _unreachedSaid = false;
    // A stop took the task over while its report waited: the answer's follow-ups belong to a stopped run.
    if (_voided.contains(kept.offer)) return;
    // Kept as told only once its follow-ups were handed to Start: a window that ends in between tells it again, and the
    // planner answers an identical report with the same orders.
    if (await _startFollowUps(source, provider, project, kept.story!, answer.tasks, kept.offer)) {
      await _reported(kept, event, endKey, ended);
    }
  }

  /// Sends one report through the screen's run that handed [kept]'s offer to Start, which starts the answer's follow-up
  /// orders itself. Answers false where that run does not know the offer for this task, so the report goes to the
  /// source as for a task the window started itself.
  Future<bool> _throughTheScreen(
    PlannedOffer kept,
    PlanningSource source,
    PlanningTaskEvent event,
    String? endKey,
    (String, String) attempt, {
    PlanningTaskEnded? ended,
    List<PlanningLanding> landed = const [],
  }) async {
    final project = kept.project!, provider = kept.provider!;
    final at = ReportAtPlanner(kept.offer);
    Object? afterTheAnswer;
    _screen.providers = [
      PlanningProvider(name: provider, connected: true, projects: [project], source: source),
    ];
    try {
      await at.watch(
        () => _screen.taskEvent(
          project,
          kept.task!,
          event,
          offer: kept.offer,
          container: kept.container,
          machine: kept.machine,
          ended: ended,
          landed: landed,
        ),
      );
    } on Object catch (error, stack) {
      // The run refuses an offer it holds no start of for this task before it asks the planner: the source is asked
      // as for a task the window started itself.
      if (!at.asked && planningRefused(error, 'TaskEventConflict')) return false;
      // Not asked for another refusal of the run's, or asked and not answered: the planner did not take the report.
      if (!at.answered) {
        await _notTaken(kept, error, stack, attempt, event: event, source: source);
        return true;
      }
      // The planner took the report; what the run could not start after its answer, a refusal or a start that failed
      // before, is said, and neither the report nor its follow-ups are sent again.
      afterTheAnswer = error;
    }
    _unreachedSaid = false;
    if (_voided.contains(kept.offer)) return true;
    await _reported(kept, event, endKey, ended);
    if (afterTheAnswer != null) _say(provider, project, afterTheAnswer);
    return true;
  }

  /// A report the planner did not take: a task it no longer answers for is stopped and forgotten, a refusal that will
  /// not change by itself is not sent again in this window's life, and either is thrown to be said.
  Future<void> _notTaken(
    PlannedOffer kept,
    Object error,
    StackTrace stack,
    (String, String) attempt, {
    required PlanningTaskEvent event,
    required PlanningSource source,
  }) async {
    if (error is PlanningRefusal) {
      if (error.name == 'TaskNotAnswered') return _voidTask(kept);
      if (!_transient(error)) _refused.add(attempt);
      // The planner's save of the start was refused, which halts the run while it holds the task started: the task
      // stops and its end is told, so the story can start again. A refusal the run makes before it saves halts
      // nothing, and the task is kept.
      if (event == PlanningTaskEvent.started && !_transient(error) && !_beforeTheSave.contains(error.name)) {
        _voided.add(kept.offer);
        if (starts.machineNamed(kept.machine) case final machine?) {
          await _stopAndEnd(machine, kept.container, kept, source);
        }
      }
    } else {
      _refused.add(attempt);
    }
    Error.throwWithStackTrace(error, stack);
  }

  /// Keeps that [kept]'s report of [event] was taken.
  Future<void> _reported(PlannedOffer kept, PlanningTaskEvent event, String? endKey, PlanningTaskEnded? ended) =>
      settings.planningOfferReported(
        kept.machine,
        kept.container,
        started: event == PlanningTaskEvent.started ? true : null,
        ended: endKey,
        landed: event == PlanningTaskEvent.landed || (ended?.landed.isNotEmpty ?? false) ? true : null,
      );

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
  /// Answers false where an order an earlier window handed could not be told started or not: the report that carried
  /// it is then told again, and the planner's answer carries the order again.
  Future<bool> _startFollowUps(
    PlanningSource source,
    String provider,
    String project,
    String story,
    List<PlanningTaskOrder> orders,
    String reported,
  ) async {
    final started = <(PlanningTaskOrder, PlanningTaskStarted)>[];
    var settled = true;
    for (final order in orders) {
      if (_voided.contains(reported)) break;
      final offer = order.offer;
      if (offer == null) continue;
      if (settings.planningOfferHanded(offer)) {
        final never = await _neverStarted(offer, provider, project);
        if (never == null) settled = false;
        if (never != true) continue;
      }
      try {
        started.add((order, await starts(source, project, story, order)));
      } on Object catch (error) {
        _say(provider, project, error);
        break;
      }
    }
    if (started.isNotEmpty) {
      try {
        await onFollowUps?.call(source, project, story, started);
      } on Object catch (error) {
        _say(provider, project, error);
      }
    }
    return settled;
  }

  /// Whether [offer] was handed to Start by a window that ended before Start made its task: its start is still pending,
  /// not under way in this window, and its machine lists no task with the offer as its key. Such an offer is released,
  /// so it is started again. Where the machine's tasks are not known yet, nothing can tell: the answer is null, it is
  /// not started now, and that is said once.
  Future<bool?> _neverStarted(String offer, String provider, String project) async {
    final pending = settings.pendingStarts.where((each) => each.offer == offer).firstOrNull;
    if (pending == null || starts.isStarting(offer)) return false;
    final listed = tasksOn(pending.machine);
    if (listed == null) {
      if (_undecidedSaid.add(offer)) {
        final words =
            'A task the planner ordered was handed to Start by an earlier window, which ended before Start answered, '
            'and the tasks of ${pending.machine} are not known yet: it is started once they are.';
        _say(provider, project, PlanningRefusal('FollowUpUndecided', {'detail': words}, words));
      }
      return null;
    }
    // The key alone could be another project's, as in _keepFoundAgain: a task is the offer's only in its own project.
    if (listed.any((task) => task.callerKey == offer && task.project == pending.project)) return false;
    windowLog.warn(
      'Planning: the offer $offer was handed to Start by an earlier window, which ended before its task '
      'was made on ${pending.machine}; it is started again.',
    );
    await settings.releasePlanningOffer(offer);
    return true;
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

  static String _endKey(PlanningTaskEnded ended) =>
      plannedEndKey(AgentEnded(at: ended.at, finished: ended.finished, unpushed: ended.unpushed));

  /// The planner's refusals of a task's report made before it saves its board (the run's own and those of the request
  /// itself), which halt nothing; every other one
  /// (the store's, for a board moved on, one out of reach or busy, a push only partly made) halts the run.
  static const _beforeTheSave = {
    'TaskEventConflict',
    'TaskNotAnswered',
    'WorkNotAllowed',
    'WorkRunning',
    'RunChanged',
    'PreviewChanged',
    'NoDiscussion',
    'ReadingNotStopped',
    'ReworkNeedsFindings',
    'ReadingRoundChanged',
    'WorkRecordUnavailable',
    'InvalidSettings',
    'InvalidName',
    'InvalidLevel',
    'NotACloneUrl',
    'ResultRefused',
  };

  // The planner did not answer at all, or was not asked since no watched machine named the project's repository yet; a
  // later change of a machine tries again.
  static bool _transient(PlanningRefusal refusal) =>
      const {'PlannerUnreachable', 'TimedOut', 'NoAddress', 'NoRepository'}.contains(refusal.name);
}

/// Reports a task through the planning screen's run that handed its offer to Start, as the screen's own client does,
/// to the one provider set before each report.
class _ScreenRunReports with PlanningTaskReports {
  @override
  List<PlanningProvider> providers = const [];

  @override
  String? get currentProvider => null;

  @override
  String? get chosenProject => null;

  @override
  void addListener(void Function() listener) {}

  @override
  void removeListener(void Function() listener) {}
}
