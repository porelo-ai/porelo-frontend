import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';

/// Usage: the window starts the offered reader task and it ends
Future<void> theWindowStartsTheOfferedReaderTaskAndItEnds(WidgetTester tester) => walked(
  tester,
  '9 the window starts the offered reader task and it ends',
  () async {
    // The window starts the planner's follow-up order by itself, as the answer to the builder's end.
    // The builders are no readers: they were started after the tasks were noted.
    Walk.tasksBefore = {...Walk.tasksBefore, ...Walk.builders};
    // Issues moved on to Review by hand, where their builder failed, are offered no reader.
    var allInReview = true;
    for (final issue in Walk.issues) {
      if (!await probeHolds(['issue-state', issue.id, 'Review'])) allInReview = false;
    }
    if (Walk.readers.isEmpty && allInReview) {
      noteStep('   no reader: every issue was moved on to Review by hand');
      return;
    }
    // A resume after the readers were started waits on the readers kept, not on new ones.
    if (Walk.readers.isEmpty) {
      Walk.readers = [
        for (final each in await theNewTasks(tester, 'the reader tasks', Walk.issues.length, within: Walk.taskDeadline))
          theContainerOf(each),
      ];
    }
    noteStep('   the readers run in ${Walk.readers.join(', ')}');
    for (final reader in Walk.readers) {
      await untilItEnds(tester, reader, within: Walk.taskDeadline, issue: await theIssueOf(reader));
    }
    // What the planner says of the readings counts a reader only once its offer is bound.
    await untilEveryTaskBound(tester, Walk.readers, 'the readers');
  },
);
