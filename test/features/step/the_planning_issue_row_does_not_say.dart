import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the planning issue row {id} does not say {words}
Future<void> thePlanningIssueRowDoesNotSay(WidgetTester tester, String id, String words) async {
  expect(planningText(tester, planningElement('issue-row $id')), isNot(contains(words)));
}
