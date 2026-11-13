import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/idea_walk.dart';
import '../support/planner_moves.dart';

/// Usage: the planner shows the reading's blocking findings and Needs you lists the issue
Future<void> thePlannerShowsTheReadingsBlockingFindingsAndNeedsYouListsTheIssue(WidgetTester tester) => walked(
  tester,
  "11 [findings] read: the planner shows the reading's blocking findings and Needs you lists the issue",
  () async {
    // The reader's answer ends in its Findings block, which the planner judges and keeps in its own work record, not in
    // Git. A blocking one stops the reading: the issue stays in Reading, nobody at work, under Needs you.
    await pumpUntil(
      tester,
      () async {
        Walk.stopped = [
          for (final issue in Walk.issues)
            if (await probeHolds(['attention', issue.id, 'BLOCKING_FINDINGS']))
              (id: issue.id, repository: issue.repository),
        ];
        return Walk.stopped.isNotEmpty;
      },
      timeout: const Duration(minutes: 2),
      what: 'the planner to stop a reading of ${Walk.story} on blocking findings',
    );
    for (final issue in Walk.stopped) {
      noteStep('   ${issue.id}: ${await theBlockingFindingsUnder(tester, issue.id)}');
    }
  },
);
