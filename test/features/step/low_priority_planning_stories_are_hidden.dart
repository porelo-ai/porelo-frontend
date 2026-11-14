import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';
import '../support/planning_details.dart';

/// Usage: low priority planning stories are hidden
Future<void> lowPriorityPlanningStoriesAreHidden(WidgetTester tester) async {
  await expectPlanningNowhere(tester, planningElement('card ST127'));
  await expectPlanningNowhere(tester, planningElement('card ST193'));
  await revealPlanning(tester, planningElement('card ST5'));
  expect(planningElement('card ST5'), findsOneWidget);
}
