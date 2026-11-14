import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';
import '../support/planning_details.dart';

/// Usage: the moved planning story is absent from backlog
Future<void> theMovedPlanningStoryIsAbsentFromBacklog(WidgetTester tester) async {
  await revealPlanning(tester, planningElement('card ST291'));
  expect(planningElement('card ST291'), findsOneWidget);
  await expectPlanningNowhere(
    tester,
    find.descendant(
      of: find.byKey(const Key('planning-state Backlog'), skipOffstage: false),
      matching: planningElement('card ST291'),
    ),
  );
}
