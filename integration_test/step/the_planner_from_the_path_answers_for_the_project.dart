import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';

/// Usage: the planner from the path answers for the project
Future<void> thePlannerFromThePathAnswersForTheProject(WidgetTester tester) =>
    walked(tester, '1 read: the planner from the path answers for ${Walk.project}', () async {
      // The packaged planner is tried before the path: one running from elsewhere is not the planner under test.
      expect(thePathsPlannerRuns(), isTrue, reason: 'a process of this account runs ${Walk.planner}');
      await probe(['health']);
      await probe(['faults']);
    });
