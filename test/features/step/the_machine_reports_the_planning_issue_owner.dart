import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: the machine reports the planning issue owner {owner}
Future<void> theMachineReportsThePlanningIssueOwner(WidgetTester tester, String owner) async {
  reportPlanningOwner(owner);
}
