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
import '../app/window_log.dart';
import '../client/models.dart' show AgentEnded, Mode, Task;
import '../client/porelo_client.dart' show FeatureNotSupported, StartProgress;
import '../wire/varlink_exception.dart';
import 'planning_reports.dart';
import 'start_work_view.dart' show StartAgentChoice;

/// What the planning place says where the window was given no planning: planning is the planner's, not the window's.
const planningNotReached = 'Planning comes from porelo-planner, which this window does not reach yet.';

/// The selected machine while it is watched, else null: one not opened yet cannot take work.
Machine? _watchedCurrent(Machines machines) =>
    machines.all.isEmpty || machines.watching(machines.current) == null ? null : machines.current;

/// The machine a task the planner orders for a project runs on: one of [watched] that carries the project, its host
/// where a host carries it, otherwise [current], the machine the window is connected to.
Machine? plannedTaskMachine(Iterable<Machine> watched, Machine? current, bool Function(Machine) carries) {
  final carrying = [
    if (current != null && carries(current)) current,
    ...watched.where((machine) => machine != current && carries(machine)),
  ];
  return carrying.where((machine) => machine.kind == 'host').firstOrNull ?? carrying.firstOrNull ?? current;
}

/// The agent and model a person chose for a discussion of an idea, or null where they turned it away.
typedef DiscussionChoice = ({String agent, String model});

/// Asks the person on [machine] which agent and model discuss [task]'s idea for [project].
typedef ChooseDiscussion = Future<DiscussionChoice?> Function(Machine machine, String project, PlanningTaskOrder task);

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
      _watchedCurrent(machines),
      (machine) => machines.watching(machine)?.listedProjects.any((each) => each.name == project) ?? false,
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

  /// Asks the person for a discussion's agent and model; where none asks, the order's own are taken.
  ChooseDiscussion? chooseDiscussion;

  /// Told the task a discussion started, as the machine lists it, so the person is shown its session.
  void Function(Machine machine, Task task)? onDiscussionStarted;

  /// Told what a refused planned Start said, so the person sees it at once, beside the planning screen's own line.
  void Function(String words)? onStartRefused;

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
  /// A discussion of an idea is the person's: they choose its agent and model through [chooseDiscussion], and it starts
  /// over every repository of the project, read only, as no story's task.
  ///
  /// A refusal, by the machine or for want of one, is a [PlanningRefusal] in the machine's words.
  Future<PlanningTaskStarted> call(PlanningSource source, String project, String story, PlanningTaskOrder task) async {
    final offer = task.offer;
    if (offer != null) _starting.add(offer);
    try {
      return await _start(source, project, story, task);
    } finally {
      if (offer != null) _starting.remove(offer);
    }
  }

  final _starting = <String>[];

  /// Whether a start of [offer] runs in this window: its task is kept by that start, never by a sweep.
  bool isStarting(String offer) => _starting.contains(offer);

  Future<PlanningTaskStarted> _start(
    PlanningSource source,
    String project,
    String story,
    PlanningTaskOrder task,
  ) async {
    final machine = machineFor(project);
    if (machine == null) {
      const words = 'No watched machine to start the task on. Watch the machine that carries the project.';
      throw PlanningRefusal('NoMachine', {'detail': words}, words);
    }
    final backend = backendOf(machine);
    final discussion = task.role == 'DISCUSSION';
    final Future<StartProgress> Function() start;
    switch ((discussion, task.repository, task.result)) {
      case (true, _, final result?):
        // Asked before the offer is handed and before the person chooses: a machine that cannot is said at once.
        final String? why;
        try {
          why = await Future.sync(backend.whyNoDiscussion);
        } on Exception catch (error) {
          final words = 'Whether ${machine.name} can start a discussion could not be read: $error';
          throw PlanningRefusal('StartRefused', {'detail': words}, words);
        }
        if (why != null) throw PlanningRefusal('NoDiscussion', {'detail': why}, why);
        final chosen = await (chooseDiscussion ?? _asOrdered)(machine, project, task);
        if (chosen == null) {
          const words = 'The discussion was not started.';
          throw const PlanningRefusal('NotStarted', {'detail': words}, words);
        }
        // The person chose for the machine the form named; one no longer watched, or no longer the project's, is
        // never started on in its place.
        if (!identical(machineFor(project), machine)) {
          final words = '${machine.name} no longer carries $project for this window; the discussion was not started.';
          throw PlanningRefusal('NoMachine', {'detail': words}, words);
        }
        start = () => backend.startDiscussion(
          project: project,
          agent: chosen.agent,
          model: chosen.model,
          mode: Mode(task.mode),
          prompt: task.prompt,
          result: result,
          callerKey: task.offer,
        );
      case (false, final repository?, _):
        start = () => backend.startOrdered(
          project: project,
          repository: repository,
          agent: task.agent,
          model: task.model,
          mode: Mode(task.mode),
          prompt: task.prompt,
          callerKey: task.offer,
          reads: task.reads,
        );
      default:
        final words = 'The planner ordered a ${task.role} task this window cannot start.';
        throw PlanningRefusal('UnknownOrder', {'detail': words}, words);
    }
    // Handed before Start is asked: whatever Start answers, this offer is never started again.
    if (task.offer case final offer?) {
      if (settings.planningOfferHanded(offer)) {
        const words = 'This offer has already been handed to Start.';
        throw const PlanningRefusal('OfferConsumed', {'detail': words}, words);
      }
      // Kept until its task is: a window that ends before Start answers finds the task again by the offer.
      await settings.handPlanningOffer(
        offer,
        pending: switch (providerOf(source)) {
          final provider? => PendingStart(
            offer: offer,
            machine: machine.name,
            provider: provider,
            project: project,
            story: story,
            discussion: discussion,
          ),
          null => null,
        },
      );
    }
    final StartProgress answer;
    try {
      answer = await start();
    } on VarlinkException catch (error) {
      await _refused(task.offer);
      _sayRefused(machine, project, story, task, error.toString());
      throw PlanningRefusal(error.simpleName, error.parameters, error.toString(), error.isMethodNotFound);
    } on Exception catch (error) {
      await _refused(task.offer);
      _sayRefused(machine, project, story, task, '$error');
      // The window's refusals of a start, each already in words.
      throw PlanningRefusal('StartRefused', {'detail': '$error'}, '$error');
    }
    final container = answer.container ?? '';
    if (container.isEmpty || !_started(answer)) {
      await _refused(task.offer);
      final printed = answer.output.join('\n').trim();
      final words = printed.isNotEmpty
          ? printed
          : '${machine.name} answered Start with ${answer.action?.name ?? 'no action'} and exit code '
                '${answer.exitCode ?? 'none'}, starting no task.';
      _sayRefused(machine, project, story, task, words);
      throw PlanningRefusal('StartRefused', {'detail': words}, words);
    }
    _startedOn[(project, container)] = machine;
    // Start answers the container alone; the task's name within the project is what the machine lists for it.
    final listed = (await backend.tasks()).where((each) => each.name == container).firstOrNull;
    final name = listed?.task ?? '';
    if (name.isEmpty) {
      final words = '${machine.name} started $container but does not list its task name.';
      throw PlanningRefusal('NotListed', {'detail': words}, words);
    }
    if ((discussion, listed) case (true, final started?)) {
      // Its idea is handed in when it ends, with its offer; an end it showed as it started is an earlier run's.
      if ((task.offer, providerOf(source)) case (final offer?, final provider?)) {
        await settings.rememberDiscussion(
          machine: machine.name,
          container: container,
          offer: offer,
          provider: provider,
          project: project,
          ended: switch (started.agentEnded) {
            final ended? => plannedEndKey(ended),
            null => null,
          },
        );
      }
      onDiscussionStarted?.call(machine, started);
    }
    // A discussion is no story's task: its end is the person's, not a run's to report.
    if ((task.offer, providerOf(source)) case (final offer?, final provider?) when !discussion) {
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
        run: listed?.run,
      );
      if (settings.plannedOffer(machine.name, container) case final kept?) onConfirmed?.call(kept);
    }
    return PlanningTaskStarted(task: name, container: container);
  }

  /// Writes a refused Start of [task] to the window's log and tells [onStartRefused], alike on every way Start refuses:
  /// what the person asked for is never lost to a quiet line alone.
  void _sayRefused(Machine machine, String project, String story, PlanningTaskOrder task, String words) {
    final what = task.role == 'DISCUSSION'
        ? 'a discussion'
        : 'the ${task.role.toLowerCase()} task of $story${task.repository == null ? '' : ' in ${task.repository}'}';
    final said = 'Start of $what for $project on ${machine.name} was refused: $words';
    windowLog.warn('Planning: $said', machine: machine.name);
    onStartRefused?.call(said);
  }

  /// No task stands for [offer]: nothing is left to find again.
  Future<void> _refused(String? offer) async {
    if (offer != null) await settings.forgetPendingStart(offer);
  }

  static Future<DiscussionChoice?> _asOrdered(Machine machine, String project, PlanningTaskOrder task) async =>
      (agent: task.agent, model: task.model);

  // A start that went through answers CREATE or RESUME; an older Porelo bringing a task back answers no action, exit 0.
  // One that made its task and then failed answers its action with an exit code other than 0: no task stands.
  static bool _started(StartProgress answer) => switch ((answer.action, answer.exitCode)) {
    (_, final code?) when code != 0 => false,
    (null, final code) => code == 0,
    (final action?, _) => action.starts,
  };
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
  const EmbeddedPlanning(this.client, {required this.startTask, this.startedOn = _nowhere, this.reports, this.starts});

  /// The providers of planning, one per machine that serves it.
  final PlanningClient client;

  /// How a task of story work is started.
  final PlanningStartTask startTask;

  /// The machine a task [startTask] started for a project runs on, by its container, or null where it does not know.
  final Machine? Function(String project, String container) startedOn;

  /// How the tasks [startTask] started are reported, followed and stopped, absent where nothing reports them.
  final WindowTaskReports? reports;

  /// The window's start of the planner's orders, where the window asks the person through it.
  final WindowTaskStarts? starts;

  static Machine? _nowhere(String project, String container) => null;
}

/// The window's planning: this computer's planner, found or started once, its board read through the planner's own
/// client, its tasks started on the watched machines.
///
/// Its reports look at the kept offers whenever a machine or the planner changes, so an end that came while the window
/// was closed is reported once both answer.
EmbeddedPlanning plannerPlanning(LocalPlanner planner, Machines machines) {
  final starts = WindowTaskStarts.of(machines, planner);
  final reports = WindowTaskReports.of(machines, planner, starts, runtimeDirectory: planner.runtimeDirectory);
  planner.reports = reports.report;
  machines.addListener(reports.sweep);
  planner.addListener(reports.sweep);
  return EmbeddedPlanning(
    planner,
    startTask: starts.call,
    startedOn: starts.startedOn,
    reports: reports,
    starts: starts,
  );
}

/// The watched machine that [client] names as the provider of [source], if one still is.
///
/// A provider is named as the machine it stands for, so the window finds the tasks of a run where the machine keeps
/// them. A provider named as no machine, as the planner on the path is, has its tasks where the window starts them:
/// on the machine that carries [project], by default the client's chosen one; where neither is known, as when the
/// planning screen chose its board's project itself, a project the provider lists.
Machine? planningMachineOf(Machines machines, PlanningClient client, PlanningSource source, {String? project}) {
  final provider = client.providers.where((provider) => identical(provider.source, source)).firstOrNull;
  if (provider == null) return null;
  final named = machines.all.where((machine) => machine.name == provider.name).firstOrNull;
  if (named != null) return named;
  final carried = switch (project ?? client.chosenProject) {
    final known? => {known},
    null => provider.projects.toSet(),
  };
  if (carried.isEmpty) return null;
  return plannedTaskMachine(
    machines.all,
    _watchedCurrent(machines),
    (machine) => machines.watching(machine)?.listedProjects.any((each) => carried.contains(each.name)) ?? false,
  );
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
  /// Finds each provider's machine among [machines] by the name [client] gives it, or by the [project] the person
  /// plans.
  const MachinePlanningAgents(this.machines, this.client, {this.project = _noProject});

  static String? _noProject() => null;

  /// The project the person plans, whose machine a planner named as no machine starts on.
  final String? Function() project;

  /// The watched machines.
  final Machines machines;

  /// The providers of planning, each named as its machine.
  final PlanningClient client;

  @override
  Future<PlanningAgentList> on(PlanningSource source) async {
    final machine = planningMachineOf(machines, client, source, project: project());
    if (machine == null) {
      final followed = client.providers.any((provider) => identical(provider.source, source));
      throw StateError(switch ((followed, project() ?? client.chosenProject)) {
        (false, _) => 'This window no longer follows ${source.label}.',
        (true, null) => 'This window does not know which project ${source.label} starts on.',
        (true, final project?) => 'This window no longer knows the machine that carries $project.',
      });
    }
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
