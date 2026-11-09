import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: the machine lists planning issue {issue} under story {story}
Future<void> theMachineListsPlanningIssueUnderStory(WidgetTester tester, String issue, String story) =>
    listPlanningIssueUnder(tester, issue, story);
