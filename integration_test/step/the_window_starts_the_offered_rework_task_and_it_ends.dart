import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';
import '../support/results_land.dart';

/// Usage: the window starts the offered rework task and it ends
Future<void> theWindowStartsTheOfferedReworkTaskAndItEnds(WidgetTester tester) => walked(
  tester,
  '13 [findings] the window starts the offered rework task and it ends',
  () async {
    // The window starts the planner's follow-up order by itself, as it starts the readers: one rework per repository
    // of an issue whose reading stopped, with the reading's blocking findings.
    Walk.tasksBefore = {...Walk.tasksBefore, ...Walk.readers};
    final repositories = {for (final issue in await theBlockedIssues()) issue.repository};
    final reworks = [
      for (final each in await theNewTasks(tester, 'the rework tasks', repositories.length, within: Walk.taskDeadline))
        theContainerOf(each),
    ];
    noteStep('   the reworks run in ${reworks.join(', ')}');
    for (final rework in reworks) {
      await untilItEnds(tester, rework, within: Walk.taskDeadline, issue: await theIssueOf(rework));
    }
  },
);
