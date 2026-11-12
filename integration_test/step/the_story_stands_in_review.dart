import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/idea_walk.dart';

/// Usage: the story stands in Review
Future<void> theStoryStandsInReview(WidgetTester tester) =>
    walked(tester, '9 read: the story stands in Review', () async {
      // The window posts the reader's end once porelo lists it; the planner's move follows, or the reader's findings
      // could not be read.
      await pumpUntil(
        tester,
        () async =>
            await probeHolds(['story-state', Walk.story!, 'Review']) ||
            await probeHolds(['attention', Walk.issues.first.id, 'INVALID_FINDINGS']),
        timeout: const Duration(minutes: 5),
        what: 'the planner to move ${Walk.story} to Review',
      );
      // The operator's order for this run: findings the planner cannot read are corrected by hand, in the window,
      // by moving the issue on to Review, and noted.
      for (final issue in Walk.issues) {
        if (await probeHolds(['attention', issue.id, 'INVALID_FINDINGS'])) {
          noteStep('   HAND: ${issue.id} has INVALID_FINDINGS; the person moves it from Reading to Review');
          await toTheStory(tester);
          await moveAndSave(tester, issue.id, 'Review');
        }
      }
      await pumpUntil(
        tester,
        () => probeHolds(['story-state', Walk.story!, 'Review']),
        timeout: const Duration(minutes: 2),
        what: 'the planner to move ${Walk.story} to Review',
      );
      for (final issue in Walk.issues) {
        await theIssueStandsIn(issue.id, issue.repository, 'Review');
      }
      await probe(['story-state', Walk.story!, 'Review']);
      await probe(['work', Walk.story!, 'ended']);
    });
