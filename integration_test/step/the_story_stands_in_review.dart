import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/idea_walk.dart';

/// Usage: the story stands in Review
Future<void> theStoryStandsInReview(WidgetTester tester) =>
    walked(tester, '9 read: the story stands in Review', () async {
      // The window posts the reader's end once porelo lists it; the planner's move follows, or the reader's findings
      // could not be read.
      Future<bool> readOrRaised(String issue) async =>
          await probeHolds(['issue-state', issue, 'Review']) ||
          await probeHolds(['attention', issue, 'INVALID_FINDINGS']) ||
          await probeHolds(['attention', issue, 'FAILED']);
      await pumpUntil(
        tester,
        () async {
          if (await probeHolds(['story-state', Walk.story!, 'Review'])) return true;
          for (final issue in Walk.issues) {
            if (!await readOrRaised(issue.id)) return false;
          }
          return true;
        },
        timeout: const Duration(minutes: 5),
        what: 'the planner to move ${Walk.story} to Review',
      );
      // The operator's order for this run: findings the planner cannot read are corrected by hand, in the window,
      // by moving the issue on to Review, and noted.
      // A reader that failed is repaired by hand the same way, so the run goes on to its end; the failure is noted.
      for (final issue in Walk.issues) {
        final raised = [
          for (final reason in ['INVALID_FINDINGS', 'FAILED'])
            if (await probeHolds(['attention', issue.id, reason])) reason,
        ].firstOrNull;
        if (raised != null) {
          noteStep('   HAND: ${issue.id} has $raised; the person moves it from Reading to Review');
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
