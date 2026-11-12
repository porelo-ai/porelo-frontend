import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';

/// Usage: porelo on the machine says the discussion ran and ended
Future<void> poreloOnTheMachineSaysTheDiscussionRanAndEnded(WidgetTester tester) =>
    walked(tester, '2 read: porelo says the discussion ran and ended', () async {
      // A discussion reads the whole project, so its end removes it: no longer listed is its end. That it ran is read
      // from what it handed in, the story the next step reads from the planner.
      expect(await isGone(Walk.discussion!), isTrue, reason: 'porelo still lists ${Walk.discussion}');
      // Nothing is saved for a discussion; the project's tip is read to show the forge answers.
      noteStep('   the project repository stands at ${(await probe(['forge-head', Walk.ownUrl])).trim()}');
    });
