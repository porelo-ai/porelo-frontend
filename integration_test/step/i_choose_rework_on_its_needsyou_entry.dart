import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';
import '../support/planner_moves.dart';

/// Usage: I choose Rework on its Needs-you entry
Future<void> iChooseReworkOnItsNeedsyouEntry(WidgetTester tester) =>
    walked(tester, "11 [needs-you-offer] the person chooses Rework on the second's Needs-you entry", () async {
      // The readers are no reworks: they were started before.
      Walk.tasksBefore = {...Walk.tasksBefore, ...Walk.readers};
      final second = theSecondIssue();
      // Taken up again after Rework was sent: the planner set the issue on, or the window started its rework.
      final reworks = [
        for (final each in await theProjectsTasks())
          if (!Walk.tasksBefore.contains(theContainerOf(each)) && each['repository'] == second.repository)
            theContainerOf(each),
      ];
      for (final state in ['Rework', 'Reworking']) {
        if (await probeHolds(['issue-state', second.id, state])) {
          noteStep('   Rework was chosen already: ${second.id} stands in $state');
          return;
        }
      }
      if (reworks.isNotEmpty) {
        noteStep('   Rework was chosen already: its rework runs in ${reworks.join(', ')}');
        return;
      }
      await chooseRework(tester, second.id);
    });
