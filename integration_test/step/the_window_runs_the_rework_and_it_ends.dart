import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';

/// Usage: the window runs the rework and it ends
Future<void> theWindowRunsTheReworkAndItEnds(WidgetTester tester) =>
    walked(tester, '12 [needs-you-offer] the second stands in Reworking and the window runs its rework', () async {
      // Chosen, the planner sets Reworking and offers the rework with the blocking findings; the window starts it by
      // itself, as it starts the readers.
      Walk.tasksBefore = {...Walk.tasksBefore, ...Walk.readers};
      final second = Walk.issues.firstWhere((each) => each.repository == Walk.issueRepositories[1]);
      final rework = theContainerOf(await theNewTask(tester, 'the rework task', within: Walk.taskDeadline));
      if (await theIssueOf(rework) != second.id) fail('asked $rework for the rework of ${second.id}; it works another');
      await theIssueStandsIn(second.id, second.repository, 'Reworking');
      noteStep('   the rework runs in $rework');
      await untilItEnds(tester, rework, within: Walk.taskDeadline, issue: second.id);
    });
