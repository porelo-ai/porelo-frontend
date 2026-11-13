import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: planning warns that moving {id} stops its running work
Future<void> planningWarnsThatMovingStopsItsRunningWork(WidgetTester tester, String id) async {
  // Saving a move over running work without asking, or not saying the tasks stop, makes this fail.
  expect(planningElement('move-warning'), findsOneWidget);
  expect(
    planningText(tester, find.byKey(Key('planning-move-warning-item RUNNING_WORK $id'))),
    contains('has agent tasks at work, stopped first'),
  );
  expect(
    find.descendant(of: planningElement('move-confirm'), matching: find.text('Stop the tasks and move')),
    findsOneWidget,
  );
}
