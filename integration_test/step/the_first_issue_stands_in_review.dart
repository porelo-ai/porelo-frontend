import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/idea_walk.dart';

/// Usage: the first issue stands in Review
Future<void> theFirstIssueStandsInReview(WidgetTester tester) =>
    walked(tester, '9 [planner-moves] read: the first issue stands in Review', () async {
      // The first issue repository's work passes its reader: the planner sets Review, nobody moves it.
      final first = Walk.issues.firstWhere((each) => each.repository == Walk.issueRepositories.first);
      await pumpUntil(
        tester,
        () => probeHolds(['issue-state', first.id, 'Review']),
        timeout: const Duration(minutes: 5),
        what: 'the planner to set ${first.id} to Review',
      );
      await theIssueStandsIn(first.id, first.repository, 'Review');
    });
