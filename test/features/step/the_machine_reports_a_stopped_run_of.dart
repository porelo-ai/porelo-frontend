import 'package:flutter_test/flutter_test.dart';

import 'the_machine_reports_a_run_of_whose_issue_needs_you_for.dart';

/// Usage: the machine reports a stopped run of {story}
Future<void> theMachineReportsAStoppedRunOf(WidgetTester tester, String story) =>
    theMachineReportsARunOfWhoseIssueNeedsYouFor(tester, story, 'STOPPED');
