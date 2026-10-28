import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the task {'payments-api'} of {'checkout'} in {'payments-api'} runs before the machine says its agent
///
/// As a machine lists a task in the first seconds after its start: running, its agent and mode not said yet.
Future<void> theTaskOfInRunsBeforeTheMachineSaysItsAgent(
  WidgetTester tester,
  String task,
  String project,
  String repository,
) async {
  World.backend.bringsUp(
    Task.from(<String, dynamic>{...wire(World.anAgentsTask('', repository, project, task, running: true)), 'mode': ''}),
  );
  await World.settle(tester);
}
