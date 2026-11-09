import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: the machine reports malformed planning blockers
Future<void> theMachineReportsMalformedPlanningBlockers(WidgetTester tester) async {
  await reportMalformedPlanningBlockers(tester);
}
