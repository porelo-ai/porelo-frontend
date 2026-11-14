import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: closed planning states start folded
Future<void> closedPlanningStatesStartFolded(WidgetTester tester) async {
  // Done holds the closed states and starts folded: its boxes and their stories stand as tiles, without their titles.
  expect(planningElement('state Finished'), findsOneWidget);
  expect(planningElement('state Rejected'), findsOneWidget);
  expect(planningElement('card ST264'), findsOneWidget);
  expect(find.textContaining('A host prepared with no project or person'), findsNothing);
}
