import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/idea_walk.dart';

/// Usage: the builder task runs and the story stands in Implementing
Future<void> theBuilderTaskRunsAndTheStoryStandsInImplementing(WidgetTester tester) =>
    walked(tester, '6 read: the builder task runs and the story stands in Implementing', () async {
      final task = await theTask(Walk.builder!);
      // A small task may have ended already by the time it is read.
      expect(task['running'] == true || hasEnded(task), isTrue, reason: 'porelo says ${Walk.builder} ran: $task');
      // The window posts STARTED after Start confirmed it; the planner moves on its own word.
      await pumpUntil(
        tester,
        () => probeHolds(['work', Walk.story!, 'started']),
        timeout: const Duration(minutes: 2),
        what: 'the planner to have the run started',
      );
      await probe(['work', Walk.story!, 'started']);
      // A builder that ended already has been reported so: the planner moved its issues on to Reading.
      final state = hasEnded(await theTask(Walk.builder!)) && await probeHolds(['story-state', Walk.story!, 'Reading'])
          ? 'Reading'
          : 'Implementing';
      if (state == 'Reading') noteStep('   the builder ended before this read: the story stands in Reading already');
      for (final issue in Walk.issues) {
        await theIssueStandsIn(issue.id, issue.repository, state);
      }
      await probe(['story-state', Walk.story!, state]);
    });
