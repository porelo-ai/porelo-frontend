import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: the planning issue {id} still reports {state}
Future<void> thePlanningIssueStillReports(WidgetTester tester, String id, String state) async {
  expect(planningIssueReportedState(tester, id), state);
}
