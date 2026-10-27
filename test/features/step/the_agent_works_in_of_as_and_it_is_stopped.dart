import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the agent {'an-agent'} works in {'payments-api'} of {'checkout'} as {'payments-api'} and it is stopped
Future<void> theAgentWorksInOfAsAndItIsStopped(
  WidgetTester tester,
  String agent,
  String repository,
  String project,
  String task,
) async {
  World.backend.bringsUp(World.anAgentsTask(agent, repository, project, task, running: false));
  await World.settle(tester);
}
