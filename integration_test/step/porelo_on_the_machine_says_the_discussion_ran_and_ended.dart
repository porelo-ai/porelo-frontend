import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';

/// Usage: porelo on the machine says the discussion ran and ended
Future<void> poreloOnTheMachineSaysTheDiscussionRanAndEnded(WidgetTester tester) =>
    walked(tester, '2 read: porelo says the discussion ran and ended', () async {
      // Ended, or gone already: the window removes an ended discussion once the planner saved its idea. That it ran is
      // read from what it handed in, the story the next step reads from the planner.
      if (!await isGone(Walk.discussion!)) {
        final task = await theTask(Walk.discussion!);
        expect(hasEnded(task), isTrue, reason: 'porelo says ${Walk.discussion} ended: $task');
      }
      // Nothing is saved for a discussion; the project's tip is read to show the forge answers.
      noteStep('   the project repository stands at ${(await probe(['forge-head', Walk.ownUrl])).trim()}');
    });
