import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: planning does not warn that moving {id} stops work
Future<void> planningDoesNotWarnThatMovingStopsWork(WidgetTester tester, String id) async {
  // A start the planner was told of, or a task that ended, still warned of as a start handed on makes this fail.
  expect(find.byKey(Key('planning-move-warning-item RUNNING_WORK $id')), findsNothing);
  expect(find.text('Stop the tasks and move'), findsNothing);
}
