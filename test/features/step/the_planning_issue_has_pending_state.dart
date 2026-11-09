import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the planning issue {id} has pending state {state}
Future<void> thePlanningIssueHasPendingState(WidgetTester tester, String id, String state) async {
  expect(planningText(tester, planningElement('move-pending $id')), 'Pending: $state');
}
