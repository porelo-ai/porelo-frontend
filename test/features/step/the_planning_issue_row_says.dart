import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the planning issue row {id} says {words}
Future<void> thePlanningIssueRowSays(WidgetTester tester, String id, String words) async {
  expect(planningText(tester, planningElement('issue-row $id')), contains(words));
}
