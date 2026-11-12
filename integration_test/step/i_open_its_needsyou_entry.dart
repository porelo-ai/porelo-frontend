import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/idea_walk.dart';
import '../support/planner_moves.dart';

/// Usage: I open its Needs-you entry
Future<void> iOpenItsNeedsyouEntry(WidgetTester tester) =>
    walked(tester, '11 [needs-you-offer] the person opens the Needs-you entry', () async {
      final second = Walk.issues.firstWhere((each) => each.repository == Walk.issueRepositories[1]);
      PlannerMoves.tasksBeforeOpening = {for (final each in await theProjectsTasks()) theContainerOf(each)};
      await toThePlace(tester, 'attention');
      final entry = theEntryOf(second.id);
      await tester.ensureVisible(entry.first);
      await tester.tap(entry.first);
      await pumpFor(tester);
    });
