import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine starts a discussion over every repository with the agent {agent}
Future<void> theMachineStartsADiscussionOverEveryRepositoryWithTheAgent(WidgetTester tester, String agent) async {
  final started = World.backend.discussed.single;
  expect(started.agent, agent);
  expect(started.result, 'idea.json');
  expect(started.mode.name, 'AGENT');
}
