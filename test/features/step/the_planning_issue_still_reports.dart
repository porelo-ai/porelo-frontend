import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: the planning issue {id} still reports {state}
Future<void> thePlanningIssueStillReports(WidgetTester tester, String id, String state) async {
  expect(planningIssueStateText(tester, id).split('Pending:').first.trim(), state);
}
