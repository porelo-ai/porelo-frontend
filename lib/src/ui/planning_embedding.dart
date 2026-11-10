import 'package:flutter/widgets.dart';
import 'package:porelo_planning/porelo_planning.dart'
    show
        PlanningAgent,
        PlanningAgentList,
        PlanningAgents,
        PlanningBoard,
        PlanningHost,
        PlanningPlace,
        PlanningSource,
        PlanningTaskChanges,
        StoryWork;

import '../app/links.dart' as links;
import '../app/planning_daemon.dart';
import '../app/shell_model.dart';
import 'start_work_view.dart' show StartAgentChoice;

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

/// The agents a machine's daemon offers a start, shown as the window's start shows them.
class DaemonPlanningAgents implements PlanningAgents {
  /// Asks each source's own daemon.
  const DaemonPlanningAgents();

  @override
  Future<PlanningAgentList> on(PlanningSource source) async {
    final listed = await (source as FleetPlanningSource).agentsOn();
    return PlanningAgentList([
      for (final agent in listed.agents) PlanningAgent(agent.name, choice: StartAgentChoice(agent: agent)),
    ], listed.failures);
  }
}
