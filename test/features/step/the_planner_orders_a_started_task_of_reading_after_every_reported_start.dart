import '../../support/planned_orders.dart';

import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the planner orders a started task of {story} reading {issue} after every reported start
Future<void> thePlannerOrdersAStartedTaskOfReadingAfterEveryReportedStart(
  WidgetTester tester,
  String story,
  String issue,
) async {
  await World.settle(tester);
  final started = World.settings.plannedOffers.where((kept) => kept.story == story).toList();
  expect(started, isNotEmpty, reason: 'a task of $story was started');
  expect(started.every((kept) => kept.startedReported), isTrue, reason: 'the starts of $story were reported');
  // An offer the board's run of another story already handed to Start: the run refuses to start it again.
  World.planning
    ..followUpEveryStart = true
    ..followUpOnStart = {
      'offer': started.first.offer,
      'repository': 'porelo',
      'issues': [issue],
      ...workOrder(readerRole, const <String, dynamic>{}),
      'readLanded': ['porelo-builder-${issue.toLowerCase()}'],
      'agent': 'codex',
      'model': 'a-model',
      'prompt': 'Read $issue.',
    };
}
