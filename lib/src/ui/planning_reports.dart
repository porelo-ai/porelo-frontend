import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:porelo_planning/porelo_planning.dart';

import '../app/machines.dart';
import '../app/settings.dart';
import '../client/models.dart' show AgentEnded, Task;
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
  }) {
    starts.onConfirmed = started;
  }

  /// The watched machines' own, reporting to [client]'s providers, starting through [starts].
  factory WindowTaskReports.of(Machines machines, PlanningClient client, WindowTaskStarts starts) => WindowTaskReports(
    settings: machines.settings,
    starts: starts,
    sourceNamed: (name) => client.providers.where((provider) => provider.name == name).firstOrNull?.source,
    tasksOn: (name) => switch (machines.all.where((machine) => machine.name == name).firstOrNull) {
      final machine? => machines.of(machine).tasks,
      null => null,
    },
    stopOn: (machine, container) => machines.of(machine).stopWork(container),
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

  /// Reports refused for good in this window's life, so a refusal is not sent again on every change of the machine.
  final _refused = <(String, String, String)>{};

  /// Tasks a stop took over: whatever report of them still waits is not sent.
  final _voided = <(String, String)>{};

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
      _voided.add((machine.name, task.container));
      try {
        await stopOn(machine, task.container);
      } on Object catch (error) {
        _say(provider, project, error);
      }
      await settings.forgetPlanningOffer(machine.name, task.container);
    }
  }

  Future<void> _sweepNow() async {
    for (final kept in settings.plannedOffers) {
      if (!kept.reportable) {
        _sayOlder(kept);
        continue;
      }
      final task = tasksOn(kept.machine)?.where((each) => each.name == kept.container).firstOrNull;
      if (task == null) continue;
      if (!kept.startedReported) {
        await _quietly(kept, () => _deliver(kept, PlanningTaskEvent.started));
        continue;
      }
      if (task.agentEnded case final ended? when plannedEndKey(ended) != kept.ended) {
        await _quietly(kept, () => _deliver(kept, PlanningTaskEvent.ended, ended: plannedTaskEnded(ended)));
      }
    }
  }

  /// Sends one report and starts what its answer orders; a refusal that will not change by itself is not sent again in
  /// this window's life.
  Future<void> _deliver(PlannedOffer kept, PlanningTaskEvent event, {PlanningTaskEnded? ended}) async {
    final project = kept.project!, task = kept.task!, provider = kept.provider!;
    final endKey = ended == null ? null : _endKey(ended);
    final attempt = (kept.machine, kept.container, endKey ?? event.name);
    if (_voided.contains((kept.machine, kept.container)) || _refused.contains(attempt)) return;
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
    await settings.planningOfferReported(
      kept.machine,
      kept.container,
      started: event == PlanningTaskEvent.started ? true : null,
      ended: endKey,
    );
    await _startFollowUps(source, provider, project, kept.story!, answer.tasks);
  }

  /// The planner voided the task's offer: the task stops, its offer goes, and nothing of it is reported again.
  Future<void> _voidTask(PlannedOffer kept) async {
    _voided.add((kept.machine, kept.container));
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
  ) async {
    final started = <(PlanningTaskOrder, PlanningTaskStarted)>[];
    for (final order in orders) {
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
      debugPrint('Planning: ${planningFailureWords(error)}');
    }
  }

  static String _endKey(PlanningTaskEnded ended) =>
      plannedEndKey(AgentEnded(at: ended.at, finished: ended.finished, unpushed: ended.unpushed));

  // The planner did not answer at all; a later change of the machine tries again.
  static bool _transient(PlanningRefusal refusal) =>
      const {'PlannerUnreachable', 'TimedOut', 'NoAddress'}.contains(refusal.name);
}
