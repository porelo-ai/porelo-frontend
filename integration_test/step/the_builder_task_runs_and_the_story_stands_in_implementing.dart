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
      // A builder that ended already has been reported so: the planner moved its issue on to Reading.
      final ended = <String>{
        for (final builder in Walk.builders)
          if (hasEnded(await theTask(builder))) '${(await theTask(builder))['repository']}',
      };
      for (final issue in Walk.issues) {
        final state = ended.contains(issue.repository) && await probeHolds(['issue-state', issue.id, 'Reading'])
            ? 'Reading'
            : 'Implementing';
        if (state == 'Reading') noteStep('   ${issue.id}: its builder ended before this read; it stands in Reading');
        await theIssueStandsIn(issue.id, issue.repository, state);
      }
      final story = ended.length == Walk.issues.length && await probeHolds(['story-state', Walk.story!, 'Reading'])
          ? 'Reading'
          : 'Implementing';
      await probe(['story-state', Walk.story!, story]);
    });
