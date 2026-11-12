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
      for (final issue in Walk.issues) {
        await theIssueStandsIn(issue.id, issue.repository, 'Implementing');
      }
      await probe(['story-state', Walk.story!, 'Implementing']);
    });
