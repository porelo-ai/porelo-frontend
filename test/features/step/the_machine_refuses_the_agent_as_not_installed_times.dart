import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/start_work.dart';

import '../support/world.dart';

/// Usage: the machine refuses the agent as not installed {1} times
Future<void> theMachineRefusesTheAgentAsNotInstalledTimes(WidgetTester tester, int times) async {
  World.backend.refusesTheAgent = times;
  // Put back when the scenario ends: the next scenario in this file runs with the waits it asks for.
  final before = StartWork.askAgainAfter;
  StartWork.askAgainAfter = Duration.zero;
  addTearDown(() => StartWork.askAgainAfter = before);
}
