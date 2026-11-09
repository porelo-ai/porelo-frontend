import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: I move planning issue {id} to {state}
Future<void> iMovePlanningIssueTo(WidgetTester tester, String id, String state) async {
  await movePlanningIssue(tester, id, state);
}
