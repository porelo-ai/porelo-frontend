import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_planning/porelo_planning.dart';

import '../support/world.dart';

/// Usage: the planner was told once of each refused start
Future<void> thePlannerWasToldOnceOfEachRefusedStart(WidgetTester tester) async {
  await World.settle(tester);
  final refused = [
    for (final (offer, event) in World.planning.reported)
      if (event == PlanningTaskEvent.refused) offer,
  ];
  expect(refused, isNotEmpty, reason: 'the refused start reached the planner');
  expect(refused.toSet(), hasLength(refused.length), reason: 'each refused start was told once');
  expect(World.settings.refusedStarts, isEmpty, reason: 'the planner took it, so nothing waits to be sent again');
}
