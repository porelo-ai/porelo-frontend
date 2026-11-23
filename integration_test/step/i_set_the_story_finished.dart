import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';

/// Usage: I set the story Finished
Future<void> iSetTheStoryFinished(WidgetTester tester) =>
    walked(tester, '10 the person sets the story Finished', () async {
      // A run taken up again finds the issues the window already set Finished, and the board hides a finished story.
      final open = [
        for (final issue in Walk.issues)
          if (!await probeHolds(['issue-state', issue.id, 'Finished'])) issue,
      ];
      if (open.isEmpty) {
        noteStep('   every issue stands in Finished already');
      } else {
        await toTheStory(tester);
        for (final issue in open) {
          await moveAndSave(tester, issue.id, 'Finished');
        }
      }
      // The story waits in Review once its issues are done; the person closes it on the board.
      if (await probeHolds(['story-state', Walk.story!, 'Finished'])) return;
      await dropTheStoryOn(tester, 'Finished');
    });
