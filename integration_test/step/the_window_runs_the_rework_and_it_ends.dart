import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/idea_walk.dart';
import 'i_forward_the_work_of_each_builder_upstream_at_the_gate.dart';

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
      // The proof of the rework is the planner's own answer: the task bound to the rework offer of the second issue
      // ended, and the issue moved on from Reworking by that end.
      await pumpUntil(
        tester,
        () async => !await probeHolds(['issue-state', second.id, 'Reworking']),
        timeout: const Duration(minutes: 2),
        what: '${second.id} to move on from Reworking once its rework ended',
      );
      final after = <String>[
        for (final state in ['Reading', 'Review'])
          if (await probeHolds(['issue-state', second.id, state])) state,
      ];
      if (after.isEmpty) {
        fail('${second.id} left Reworking once its rework ended, but stands in neither Reading nor Review');
      }
      noteStep('   its rework ended and ${second.id} moved on from Reworking to ${after.first}');
      // A guarded project's gate holds the rework's push as it held the builders': the person forwards it, and only
      // then can its reader see it.
      await forwardTheWorkOf(tester, rework);
      // Reworked, the issue is read again: the window starts that reader by itself. Noted, so the driver's clean-up
      // takes it and what it pushed away with the rest.
      Walk.tasksBefore = {...Walk.tasksBefore, rework};
      final reader = theContainerOf(
        await theNewTask(tester, 'the reader of the rework', within: const Duration(minutes: 10)),
      );
      noteStep('   the rework is read again in $reader');
    });
