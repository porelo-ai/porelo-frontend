import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/idea_walk.dart';
import '../support/planner_moves.dart';
import '../support/results_land.dart';

/// Usage: the planner shows the findings worked off
Future<void> thePlannerShowsTheFindingsWorkedOff(WidgetTester tester) =>
    walked(tester, '14 [findings] read: the planner shows the findings worked off', () async {
      // After the rework the issue is read again: the window starts that reader by itself. Worked off, the reading
      // finds nothing blocking and the issue goes on to Review, needing nobody, and leaves what needs a person.
      for (final issue in await theStoppedIssues()) {
        await pumpUntil(
          tester,
          () => probeHolds(['issue-state', issue.id, 'Review']),
          timeout: Walk.taskDeadline * 2,
          what: 'the planner to read ${issue.id} again and set it to Review',
        );
        await probe(['attention', issue.id, 'NONE']);
        await toThePlace(tester, 'attention');
        await pumpUntil(
          tester,
          () => theEntryOf(issue.id).evaluate().isEmpty,
          timeout: const Duration(minutes: 2),
          what: '${issue.id} gone from what needs a person',
        );
        noteStep('   ${issue.id}: read again, in Review');
      }
    });
