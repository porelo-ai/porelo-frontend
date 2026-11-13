import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';
import '../support/planner_moves.dart';

/// Usage: I choose Rework on its Needs-you entry
Future<void> iChooseReworkOnItsNeedsyouEntry(WidgetTester tester) =>
    walked(tester, "11 [needs-you-offer] the person chooses Rework on the second's Needs-you entry", () async {
      // The readers are no reworks: they were started before.
      Walk.tasksBefore = {...Walk.tasksBefore, ...Walk.readers};
      final second = Walk.issues.firstWhere((each) => each.repository == Walk.issueRepositories[1]);
      await chooseRework(tester, second.id);
    });
