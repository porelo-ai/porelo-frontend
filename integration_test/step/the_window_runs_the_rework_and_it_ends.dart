import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
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
      // The window posts STARTED a while after porelo lists the task, and the planner sets Reworking only on that
      // word: nothing is judged before the rework is bound to its offer.
      await untilEveryTaskBound(tester, [rework], 'the rework');
      // Judged by the move itself, not by where the issue stands now: it stood in Reading before, and a quick rework
      // moves it on again. The second's repository holds that issue alone, and the run started it at its seed, so a
      // move to Reworking since the seed is the planner's for this rework; its push lands a while after the answer.
      final url = Walk.urlOf(second.repository);
      final seed = Walk.issueHeadOf(second.repository);
      await pumpUntil(
        tester,
        () async => (await probe(['forge-moved', url, seed])).contains('Move an issue to Reworking'),
        timeout: const Duration(minutes: 2),
        what: 'the forge of ${second.repository} to hold the move of ${second.id} to Reworking',
      );
      final standing = <String>[
        for (final state in ['Reworking', 'Reading', 'Review'])
          if (await probeHolds(['issue-state', second.id, state])) state,
      ];
      if (standing.isEmpty) fail('the board shows ${second.id} in none of Reworking, Reading or Review');
      if (standing.first != 'Reworking') {
        noteStep(
          '   ${second.id} was set to Reworking; its rework ended before this read, it stands in ${standing.first}',
        );
      }
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
