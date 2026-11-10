import 'package:porelo_frontend/src/app/planning_daemon.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/planning_embedding.dart';
import 'package:porelo_planning/porelo_planning.dart';

export 'package:porelo_frontend/src/app/planning_daemon.dart';

/// The planning screen as the window embeds it: the window's place, its daemons' starts and agents.
PlanningScreen planningView({
  required PlanningBoards boards,
  required ShellModel shell,
  required void Function(PlanningBoard, String) onTask,
  required String? Function(PlanningBoard, String) taskUnavailable,
  required void Function() onNeedsYou,
  Future<void> Function(StoryWork)? onStarted,
}) => PlanningScreen(
  boards: boards,
  host: ShellPlanningHost(shell, needsYou: onNeedsYou),
  startTask: daemonStartTask,
  taskChanges: WindowTaskChanges(whyNot: taskUnavailable, opening: onTask, onStarted: onStarted ?? (_) async {}),
  agents: const DaemonPlanningAgents(),
);

/// A start form whose start and agents come from the board's own daemon, as in the window.
StoryWork planningStoryWork(
  PlanningBoard board,
  PlanStory story,
  String to, {
  Map<PlanningBoard, String>? machines,
  List<String> unavailableMachines = const [],
}) => StoryWork(
  board,
  story,
  to,
  startTask: daemonStartTask,
  agentChoices: const DaemonPlanningAgents(),
  machines: machines,
  unavailableMachines: unavailableMachines,
);
