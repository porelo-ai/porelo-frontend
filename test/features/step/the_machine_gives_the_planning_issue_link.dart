import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: the machine gives the planning issue link {link}
Future<void> theMachineGivesThePlanningIssueLink(WidgetTester tester, String link) async {
  setPlanningIssueLink(link);
}
