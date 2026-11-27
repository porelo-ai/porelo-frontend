import '../../support/planned_orders.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_planning/porelo_planning.dart';

import '../support/world.dart';

/// Usage: another task of {story} reading {issue} is pressed on the board
Future<void> anotherTaskOfReadingIsPressedOnTheBoard(WidgetTester tester, String story, String issue) async {
  expect(World.planning.heldOffer, isNotNull, reason: 'the started report waits at the planner');
  // The planning screen's start hook, pressed for one more task of the same story while that report waits; whether
  // Start takes it does not matter here.
  final order = PlanningTaskOrder.from({
    'offer': '00000000-0000-4000-8000-0000000002f1',
    'repository': 'porelo',
    'issues': [issue],
    ...workOrder(readerRole, const <String, dynamic>{}),
    'readLanded': ['${story.toLowerCase()}-porelo-builder-${issue.toLowerCase()}'],
    'agent': 'codex',
    'model': 'a-model',
    'mode': 'AGENT',
    'prompt': 'Read $issue.',
  });
  World.planningStarts!.pressed(World.planning, 'checkout', story, order).ignore();
  await World.settle(tester);
}
