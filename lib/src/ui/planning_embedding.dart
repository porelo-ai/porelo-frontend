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
        PlanningUnsupported,
        PlanWorkTask,
        StoryWork,
        StoryWorkRequest,
        StoryWorkStarted;

import '../app/links.dart' as links;
import '../app/machines.dart';
import '../app/planner.dart';
import '../app/shell_model.dart';
import '../client/models.dart' show Task;
import '../client/porelo_client.dart' show FeatureNotSupported;
import '../wire/varlink_exception.dart';
import 'start_work_view.dart' show StartAgentChoice;

/// What the planning place says where the window was given no planning: planning is the planner's, not the window's.
const planningNotReached = 'Planning comes from porelo-planner, which this window does not reach yet.';

/// The runs a confirmed start reported, as the window's own tasks of [project].
List<Task> startedTasks(StoryWorkStarted? started, String project) => [
  for (final task in started?.work?.tasks ?? const <PlanWorkTask>[])
    Task.from({
      'name': task.task,
      'project': project,
      'containerId': task.containerId,
      'repository': task.repository,
      'agent': task.agent,
      'model': task.model,
      'running': task.atWork == true,
      'mode': task.mode == 'AGENT' ? 'SHELL' : task.mode,
      'state': task.state,
    }),
];

/// The running task a confirmed start names as the one to open, if it reported one.
Task? startedTerminal(StoryWorkStarted? started, String project) {
  final name = started?.terminalName;
  return startedTasks(started, project).where((task) => task.name == name && task.running).firstOrNull;
}

/// Where the window's planning place reads its boards, and how a start of story work it confirms reaches them.
class EmbeddedPlanning {
  /// Takes the providers of planning and how a start reaches the chosen one.
  const EmbeddedPlanning(this.client, {required this.startTask});

  /// The providers of planning, one per machine that serves it.
  final PlanningClient client;

  /// How a start of story work reaches the provider the person chose.
  final PlanningStartTask startTask;
}

/// The window's planning: this computer's planner, found or started once, its board read through the planner's own
/// client.
EmbeddedPlanning plannerPlanning(LocalPlanner planner) => EmbeddedPlanning(planner, startTask: plannerStartTask);

/// A start of story work through the planner, which offers none yet: refused in the screen's words, as a start the
/// provider does not offer.
Future<StoryWorkStarted> plannerStartTask(PlanningSource source, StoryWorkRequest request) async =>
    throw PlanningUnsupported('${source.label} does not offer starting story work yet');

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
  const WindowTaskChanges({required this.whyNot, required this.opening, required this.onStarted});

  /// Why a task cannot be opened now.
  final String? Function(PlanningBoard, String) whyNot;

  /// Opens a task.
  final void Function(PlanningBoard, String) opening;

  /// Shows a confirmed start's run.
  final Future<void> Function(StoryWork) onStarted;

  @override
  String? unavailable(PlanningBoard board, String task) => whyNot(board, task);

  @override
  void open(PlanningBoard board, String task) => opening(board, task);

  @override
  Future<void> started(StoryWork work) => onStarted(work);
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
