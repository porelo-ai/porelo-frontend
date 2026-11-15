import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_planning/porelo_planning.dart';

import '../support/world.dart';

/// Usage: the planner refuses the held report
Future<void> thePlannerRefusesTheHeldReport(WidgetTester tester) async {
  final hold = World.planning.heldReport;
  expect(hold, isNotNull, reason: 'a started report was held');
  // A refusal that does not change by itself: the window does not send that report again in its life.
  hold!.completeError(const PlanningRefusal('InvalidName', {}, 'The task name is invalid.'));
  await World.settle(tester);
}
