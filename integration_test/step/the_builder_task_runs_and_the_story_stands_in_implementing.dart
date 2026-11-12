import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/idea_walk.dart';

/// Usage: the builder task runs and the story stands in Implementing
Future<void> theBuilderTaskRunsAndTheStoryStandsInImplementing(WidgetTester tester) =>
    walked(tester, '6 read: the builder task runs and the story stands in Implementing', () async {
      // A small task may have ended already by the time it is read.
      for (final builder in Walk.builders) {
        final task = await theTask(builder);
        expect(task['running'] == true || hasEnded(task), isTrue, reason: 'porelo says $builder ran: $task');
      }
      // The window posts STARTED after Start confirmed it; the planner moves on its own word.
      await pumpUntil(
        tester,
        () => probeHolds(['work', Walk.story!, 'started']),
        timeout: const Duration(minutes: 2),
        what: 'the planner to have the run started',
      );
      await probe(['work', Walk.story!, 'started']);
      // A builder that ended already has been reported so: the planner moved its issue on to Reading. Its end is read
      // after the planner's state, which follows it.
      Future<bool> builderEnded(String repository) async {
        for (final builder in Walk.builders) {
          final task = await theTask(builder);
          if (task['repository'] == repository && hasEnded(task)) return true;
        }
        return false;
      }

      for (final issue in Walk.issues) {
        final state = await probeHolds(['issue-state', issue.id, 'Reading']) && await builderEnded(issue.repository)
            ? 'Reading'
            : 'Implementing';
        if (state == 'Reading') noteStep('   ${issue.id}: its builder ended before this read; it stands in Reading');
        await theIssueStandsIn(issue.id, issue.repository, state);
      }
      var allEnded = true;
      for (final issue in Walk.issues) {
        if (!await builderEnded(issue.repository)) allEnded = false;
      }
      final story = await probeHolds(['story-state', Walk.story!, 'Reading']) && allEnded ? 'Reading' : 'Implementing';
      await probe(['story-state', Walk.story!, story]);
    });
