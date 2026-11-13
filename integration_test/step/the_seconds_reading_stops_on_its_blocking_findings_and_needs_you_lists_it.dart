import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/idea_walk.dart';
import '../support/planner_moves.dart';

/// Usage: the second's reading stops on its blocking findings and Needs you lists it
Future<void> theSecondsReadingStopsOnItsBlockingFindingsAndNeedsYouListsIt(WidgetTester tester) => walked(
  tester,
  "10 [planner-moves] read: the second's reading stops on its blocking findings and Needs you lists it",
  () async {
    // The second issue repository holds the seed's fault, which its reader blocks on. The planner moves nothing on: the
    // issue stays in Reading, nobody at work, until the person chooses under Needs you.
    final second = Walk.issues.firstWhere((each) => each.repository == Walk.issueRepositories[1]);
    await pumpUntil(
      tester,
      () => probeHolds(['attention', second.id, 'BLOCKING_FINDINGS']),
      timeout: const Duration(minutes: 5),
      what: 'the planner to stop the reading of ${second.id} on blocking findings',
    );
    Walk.stopped = [(id: second.id, repository: second.repository)];
    noteStep('   ${second.id}: ${await theBlockingFindingsUnder(tester, second.id)}');
  },
);
