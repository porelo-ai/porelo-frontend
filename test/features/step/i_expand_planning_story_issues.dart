import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';
import '../support/planning_details.dart';

/// Usage: I expand planning story issues {id}
Future<void> iExpandPlanningStoryIssues(WidgetTester tester, String id) async {
  await tapPlanning(tester, planningElement('issues $id'));
}
