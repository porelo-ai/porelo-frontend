import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/planning_embedding.dart';
import 'package:porelo_frontend/src/ui/start_work_view.dart' show StartAgentChoice;
import 'package:porelo_planning/planning_fake.dart';
import 'package:porelo_planning/porelo_planning.dart';

import '../features/support/world.dart';

/// The planning screen as the window embeds it: the window's place, the stand-in's starts, its machine's agents.
PlanningScreen planningView({
  required PlanningBoards boards,
  required ShellModel shell,
  required void Function(PlanningBoard, String) onTask,
  required String? Function(PlanningBoard, String) taskUnavailable,
  required void Function() onNeedsYou,
  Future<void> Function(PlanningSource, String, String, List<(PlanningTaskOrder, PlanningTaskStarted)>)? onStarted,
}) => PlanningScreen(
  boards: boards,
  host: ShellPlanningHost(shell, needsYou: onNeedsYou),
  startTask: mockStartTask,
  taskChanges: WindowTaskChanges(
    whyNot: taskUnavailable,
    opening: onTask,
    onStarted: onStarted ?? (_, _, _, _) async {},
    onStop: (_, _, _, _) async {},
  ),
  agents: const BackendAgents(),
);

/// A start form whose start is the stand-in's and whose agents come from the board's machine, as in the window.
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
  startTask: mockStartTask,
  agentChoices: const BackendAgents(),
  machines: machines,
  unavailableMachines: unavailableMachines,
);

/// The agents the machine serving a stand-in source offers, as the window shows them.
class BackendAgents implements PlanningAgents {
  /// Asks the machine of each source.
  const BackendAgents();

  @override
  Future<PlanningAgentList> on(PlanningSource source) async {
    try {
      final listed = await World.backendOfPlanning(source).agentsOn();
      return PlanningAgentList([
        for (final agent in listed.agents) PlanningAgent(agent.name, choice: StartAgentChoice(agent: agent)),
      ], listed.failures);
    } on VarlinkException catch (error) {
      throw PlanningRefusal(error.simpleName, error.parameters, error.toString(), error.isMethodNotFound);
    }
  }
}
