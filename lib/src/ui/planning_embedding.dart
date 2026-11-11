import 'package:flutter/widgets.dart';
import 'package:porelo_planning/porelo_planning.dart'
    show
        PlanningAgent,
        PlanningAgentList,
        PlanningAgents,
        PlanningBoard,
        PlanningClient,
        PlanningHost,
        PlanningPlace,
        PlanningRefusal,
        PlanningSource,
        PlanningStartTask,
        PlanningTaskChanges,
        PlanningTaskOrder,
        PlanningTaskStarted,
        PlanningUnsupported;

import '../app/fleet_backend.dart';
import '../app/links.dart' as links;
import '../app/machines.dart';
import '../app/planner.dart';
import '../app/settings.dart';
import '../app/shell_model.dart';
import '../client/models.dart' show AgentEnded, Mode;
import '../client/porelo_client.dart' show FeatureNotSupported, StartProgress;
import '../wire/varlink_exception.dart';
import 'planning_reports.dart';
import 'start_work_view.dart' show StartAgentChoice;

/// What the planning place says where the window was given no planning: planning is the planner's, not the window's.
const planningNotReached = 'Planning comes from porelo-planner, which this window does not reach yet.';

/// The machine a task the planner orders for a project runs on: one of [watched] that carries the project, its host
/// where a host carries it, otherwise [current], the machine the window is connected to.
Machine? plannedTaskMachine(Iterable<Machine> watched, Machine? current, bool Function(Machine) carries) {
  final carrying = [
    if (current != null && carries(current)) current,
    ...watched.where((machine) => machine != current && carries(machine)),
  ];
  return carrying.where((machine) => machine.kind == 'host').firstOrNull ?? carrying.firstOrNull ?? current;
}

/// Starts each task the planner orders with Porelo's Start, on the machine that carries its project, and keeps its
/// offer beside the machine and the container Start made.
class WindowTaskStarts {
  /// Takes where a project's tasks run, how that machine is asked, and where an offer is kept.
  WindowTaskStarts({
    required this.machineFor,
    required this.backendOf,
    required this.settings,
    required this.providerOf,
    this.machineNamed = _noMachine,
  });

  /// The watched machines' own: a project's tasks run where [plannedTaskMachine] says.
  factory WindowTaskStarts.of(Machines machines, PlanningClient client) => WindowTaskStarts(
    machineFor: (project) => plannedTaskMachine(
      machines.all,
      machines.all.isEmpty ? null : machines.current,
      (machine) => machines.of(machine).listedProjects.any((each) => each.name == project),
    ),
    backendOf: (machine) => machines.of(machine).backend,
    settings: machines.settings,
    providerOf: (source) => client.providers.where((provider) => identical(provider.source, source)).firstOrNull?.name,
    machineNamed: (name) => machines.all.where((machine) => machine.name == name).firstOrNull,
  );

  /// The machine a project's tasks run on, or null where none is watched.
  final Machine? Function(String project) machineFor;

  /// How that machine is asked.
  final FleetBackend Function(Machine) backendOf;

  /// Where an offer is kept.
  final Settings settings;

  /// The name of the provider of planning whose source this is, or null where none is.
  final String? Function(PlanningSource source) providerOf;

  /// The watched machine by that name, or null where none is.
  final Machine? Function(String name) machineNamed;

  /// Told each start confirmed with its task's name.
  void Function(PlannedOffer kept)? onConfirmed;

  static Machine? _noMachine(String name) => null;

  final _startedOn = <(String, String), Machine>{};

  /// The machine a task this window started for [project] runs on, by the container Start made; after a restart, the
  /// watched machine its kept offer names.
  Machine? startedOn(String project, String container) =>
      _startedOn[(project, container)] ??
      switch (settings.plannedOffers.where((kept) => kept.container == container && kept.project == project).toList()) {
        [final kept] => machineNamed(kept.machine),
        _ => null,
      };

  /// Starts [task] of [story] for [project] with exactly what the order gives, as the planning screen's start hook.
  ///
  /// A refusal, by the machine or for want of one, is a [PlanningRefusal] in the machine's words.
  Future<PlanningTaskStarted> call(PlanningSource source, String project, String story, PlanningTaskOrder task) async {
    final machine = machineFor(project);
    if (machine == null) {
      const words = 'No watched machine to start the task on. Watch the machine that carries the project.';
      throw PlanningRefusal('NoMachine', {'detail': words}, words);
    }
    final backend = backendOf(machine);
    // Handed before Start is asked: whatever Start answers, this offer is never started again.
    if (task.offer case final offer?) await settings.handPlanningOffer(offer);
    final StartProgress answer;
    try {
      answer = await backend.startOrdered(
        project: project,
        repository: task.repository,
        agent: task.agent,
        model: task.model,
        mode: Mode(task.mode),
        prompt: task.prompt,
      );
    } on VarlinkException catch (error) {
      throw PlanningRefusal(error.simpleName, error.parameters, error.toString(), error.isMethodNotFound);
    } on Exception catch (error) {
      // The window's refusals of a start, each already in words.
      throw PlanningRefusal('StartRefused', {'detail': '$error'}, '$error');
    }
    final container = answer.container ?? '';
    if (container.isEmpty || !_started(answer)) {
      final printed = answer.output.join('\n').trim();
      final words = printed.isNotEmpty
          ? printed
          : '${machine.name} answered Start with ${answer.action?.name ?? 'no action'} and exit code '
                '${answer.exitCode ?? 'none'}, starting no task.';
      throw PlanningRefusal('StartRefused', {'detail': words}, words);
    }
    _startedOn[(project, container)] = machine;
    if (task.offer case final offer?) {
      await settings.rememberPlanningOffer(machine: machine.name, container: container, offer: offer);
    }
    // Start answers the container alone; the task's name within the project is what the machine lists for it.
    final listed = (await backend.tasks()).where((each) => each.name == container).firstOrNull;
    final name = listed?.task ?? '';
    if (name.isEmpty) {
      final words = '${machine.name} started $container but does not list its task name.';
      throw PlanningRefusal('NotListed', {'detail': words}, words);
    }
    if ((task.offer, providerOf(source)) case (final offer?, final provider?)) {
      // An end the task showed as it started is an earlier run's, never this one's.
      await settings.rememberPlanningOffer(
        machine: machine.name,
        container: container,
        offer: offer,
        provider: provider,
        project: project,
        story: story,
        task: name,
        ended: switch (listed?.agentEnded) {
          final ended? => plannedEndKey(ended),
          null => null,
        },
      );
      if (settings.plannedOffer(machine.name, container) case final kept?) onConfirmed?.call(kept);
    }
    return PlanningTaskStarted(task: name, container: container);
  }

  // A start that went through answers CREATE or RESUME; an older Porelo bringing a task back answers no action, exit 0.
  static bool _started(StartProgress answer) => answer.action == null ? answer.exitCode == 0 : answer.action!.starts;
}

/// How the window tells one end of a task's agent from another: when it ended, whether it finished, what it left.
/// Kept as a short line, whatever the machine wrote into its time.
String plannedEndKey(AgentEnded ended) {
  final key = '${ended.at}|${ended.finished}|${ended.unpushed}'.replaceAll(RegExp(r'[\x00-\x1f]'), '?');
  return key.length > 300 ? key.substring(key.length - 300) : key;
}

/// Where the window's planning place reads its boards, and how a start of story work it confirms reaches them.
class EmbeddedPlanning {
  /// Takes the providers of planning, how a start reaches a machine, and where a started task runs.
  const EmbeddedPlanning(this.client, {required this.startTask, this.startedOn = _nowhere, this.reports});

  /// The providers of planning, one per machine that serves it.
  final PlanningClient client;

  /// How a task of story work is started.
  final PlanningStartTask startTask;

  /// The machine a task [startTask] started for a project runs on, by its container, or null where it does not know.
  final Machine? Function(String project, String container) startedOn;

  /// How the tasks [startTask] started are reported, followed and stopped, absent where nothing reports them.
  final WindowTaskReports? reports;

  static Machine? _nowhere(String project, String container) => null;
}

/// The window's planning: this computer's planner, found or started once, its board read through the planner's own
/// client, its tasks started on the watched machines.
///
/// Its reports look at the kept offers whenever a machine or the planner changes, so an end that came while the window
/// was closed is reported once both answer.
EmbeddedPlanning plannerPlanning(LocalPlanner planner, Machines machines) {
  final starts = WindowTaskStarts.of(machines, planner);
  final reports = WindowTaskReports.of(machines, planner, starts);
  planner.reports = reports.report;
  machines.addListener(reports.sweep);
  planner.addListener(reports.sweep);
  return EmbeddedPlanning(planner, startTask: starts.call, startedOn: starts.startedOn, reports: reports);
}

/// The watched machine that [client] names as the provider of [source], if one still is.
///
/// A provider is named as the machine it stands for, so the window finds the tasks of a run where the machine keeps
/// them.
Machine? planningMachineOf(Machines machines, PlanningClient client, PlanningSource source) {
  final name = client.providers.where((provider) => identical(provider.source, source)).firstOrNull?.name;
  return name == null ? null : machines.all.where((machine) => machine.name == name).firstOrNull;
}

/// The planning screen's place as this window's own place, kept in the window's history.
class ShellPlanningHost implements PlanningHost {
  /// Follows [shell], and opens Needs you through [needsYou].
  ShellPlanningHost(this.shell, {required this.needsYou});

  /// The window's navigation.
  final ShellModel shell;

  /// Opens Needs you.
  final VoidCallback needsYou;

  @override
  void addListener(VoidCallback listener) => shell.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => shell.removeListener(listener);

  @override
  PlanningPlace get place => PlanningPlace(
    project: shell.place.project,
    source: shell.place.planningSource,
    story: shell.place.story,
    issue: shell.place.issue,
  );

  @override
  void go(PlanningPlace place) => shell.choosePlace(
    ShellPlace(
      Section.planning,
      project: place.project,
      planningSource: place.source,
      story: place.story,
      issue: place.issue,
    ),
  );

  @override
  Future<void> openLink(Uri address) => links.openLink(address);

  @override
  void openNeedsYou() => needsYou();
}

/// What the planning screen shows of a run, answered by the window's own task list.
class WindowTaskChanges implements PlanningTaskChanges {
  /// Takes the window's answers.
  const WindowTaskChanges({required this.whyNot, required this.opening, required this.onStarted, required this.onStop});

  /// Why a task cannot be opened now.
  final String? Function(PlanningBoard, String) whyNot;

  /// Opens a task.
  final void Function(PlanningBoard, String) opening;

  /// Shows the tasks a start confirmed, in the order they were started.
  final Future<void> Function(
    PlanningSource source,
    String project,
    String story,
    List<(PlanningTaskOrder, PlanningTaskStarted)> tasks,
  )
  onStarted;

  /// Stops tasks the planner no longer answers for, reporting nothing.
  final Future<void> Function(PlanningSource source, String project, String story, List<PlanningTaskStarted> tasks)
  onStop;

  @override
  String? unavailable(PlanningBoard board, String task) => whyNot(board, task);

  @override
  void open(PlanningBoard board, String task) => opening(board, task);

  @override
  Future<void> started(
    PlanningSource source,
    String project,
    String story,
    List<(PlanningTaskOrder, PlanningTaskStarted)> tasks,
  ) => onStarted(source, project, story, tasks);

  @override
  Future<void> stop(PlanningSource source, String project, String story, List<PlanningTaskStarted> tasks) =>
      onStop(source, project, story, tasks);
}

/// The agents the machine of a provider offers a start, shown as the window's start shows them.
class MachinePlanningAgents implements PlanningAgents {
  /// Finds each provider's machine among [machines] by the name [client] gives it.
  const MachinePlanningAgents(this.machines, this.client);

  /// The watched machines.
  final Machines machines;

  /// The providers of planning, each named as its machine.
  final PlanningClient client;

  @override
  Future<PlanningAgentList> on(PlanningSource source) async {
    final machine = planningMachineOf(machines, client, source);
    if (machine == null) throw StateError('This window no longer knows the machine of ${source.label}.');
    try {
      final listed = await machines.of(machine).backend.agentsOn();
      return PlanningAgentList([
        for (final agent in listed.agents) PlanningAgent(agent.name, choice: StartAgentChoice(agent: agent)),
      ], listed.failures);
    } on VarlinkException catch (error) {
      // In the planning screen's words, so a refusal reads there as every other refusal does.
      throw PlanningRefusal(error.simpleName, error.parameters, error.toString(), error.isMethodNotFound);
    } on FeatureNotSupported catch (error) {
      throw PlanningUnsupported(error.toString());
    }
  }
}
