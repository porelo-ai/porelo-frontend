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
      if (open.isEmpty) return noteStep('   every issue stands in Finished already');
      await toTheStory(tester);
      for (final issue in open) {
        await moveAndSave(tester, issue.id, 'Finished');
      }
    });
