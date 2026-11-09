import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';
import '../support/planning.dart';

/// Usage: I open planning issue {id}
Future<void> iOpenPlanningIssue(WidgetTester tester, String id) async {
  await tapPlanning(tester, planningElement('issue $id'));
}
