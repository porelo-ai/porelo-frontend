import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';
import '../support/results_land.dart';

/// Usage: the window starts the offered rework task and it ends
Future<void> theWindowStartsTheOfferedReworkTaskAndItEnds(WidgetTester tester) =>
    walked(tester, '12 [findings] the window starts the offered rework task and it ends', () async {
      // The window starts the planner's follow-up order by itself, as it starts the readers: one rework per issue read
      // with findings. The readers are no reworks: they were started before.
      Walk.tasksBefore = {...Walk.tasksBefore, ...Walk.readers};
      final reworks = [
        for (final each in await theNewTasks(
          tester,
          'the rework tasks',
          ResultsLand.added.length,
          within: Walk.taskDeadline,
        ))
          theContainerOf(each),
      ];
      noteStep('   the reworks run in ${reworks.join(', ')}');
      for (final rework in reworks) {
        await untilItEnds(tester, rework, within: Walk.taskDeadline, issue: await theIssueOf(rework));
      }
    });
