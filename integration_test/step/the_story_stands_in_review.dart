import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/idea_walk.dart';

/// Usage: the story stands in Review
Future<void> theStoryStandsInReview(WidgetTester tester) =>
    walked(tester, '9 read: the story stands in Review', () async {
      // The window posts the reader's end once porelo lists it; the planner's move follows.
      await pumpUntil(
        tester,
        () => probeHolds(['story-state', Walk.story!, 'Review']),
        timeout: const Duration(minutes: 5),
        what: 'the planner to move ${Walk.story} to Review',
      );
      for (final issue in Walk.issues) {
        await theIssueStandsIn(issue.id, issue.repository, 'Review');
      }
      await probe(['story-state', Walk.story!, 'Review']);
      await probe(['work', Walk.story!, 'ended']);
    });
