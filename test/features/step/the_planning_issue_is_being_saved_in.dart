import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the planning issue {id} is being saved in {state}
Future<void> thePlanningIssueIsBeingSavedIn(WidgetTester tester, String id, String state) async {
  // Showing the destination as reported before the planner answered, or no saving line at all, makes this fail.
  expect(planningText(tester, planningElement('move-pending $id')), 'Saving… $state');
}
