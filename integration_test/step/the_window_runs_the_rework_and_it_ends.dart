import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';

/// Usage: the window runs the rework and it ends
Future<void> theWindowRunsTheReworkAndItEnds(WidgetTester tester) =>
    walked(tester, '12 [needs-you-offer] the second stands in Reworking and the window runs its rework', () async {
      // Chosen, the planner sets Reworking and offers the rework with the blocking findings; the window starts it by
      // itself, as it starts the readers.
      Walk.tasksBefore = {...Walk.tasksBefore, ...Walk.readers};
      final second = theSecondIssue();
      final rework = theContainerOf(await theNewTask(tester, 'the rework task', within: Walk.taskDeadline));
      if (await theIssueOf(rework) != second.id) fail('asked $rework for the rework of ${second.id}; it works another');
      await theIssueStandsIn(second.id, second.repository, 'Reworking');
      noteStep('   the rework runs in $rework');
      await untilItEnds(tester, rework, within: Walk.taskDeadline, issue: second.id);
      // Reworked, the issue is read again: the window starts that reader by itself. Noted, so the driver's clean-up
      // takes it and what it pushed away with the rest.
      Walk.tasksBefore = {...Walk.tasksBefore, rework};
      final reader = theContainerOf(
        await theNewTask(tester, 'the reader of the rework', within: const Duration(minutes: 10)),
      );
      noteStep('   the rework is read again in $reader');
    });
