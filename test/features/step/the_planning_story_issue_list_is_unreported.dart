import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: the planning story issue list is unreported
Future<void> thePlanningStoryIssueListIsUnreported(WidgetTester tester) async {
  omitPlanningIssues();
}
