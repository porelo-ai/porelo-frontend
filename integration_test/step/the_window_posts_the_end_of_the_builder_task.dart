import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/idea_walk.dart';

/// Usage: the window posts the end of the builder task
Future<void> theWindowPostsTheEndOfTheBuilderTask(WidgetTester tester) =>
    walked(tester, '8 the window posts the end of the builder task', () async {
      // The window posts ENDED by itself once porelo lists the end; the planner's move to Reading is its effect.
      // The window starts each reader as the planner offers it, so a quick reader may have moved its issue on to Review
      // before the other builder ends: both say the end was posted.
      Future<bool> movedOrRaised(String issue) async =>
          await probeHolds(['issue-state', issue, 'Reading']) ||
          await probeHolds(['issue-state', issue, 'Review']) ||
          !await probeHolds(['attention', issue, 'NONE']);
      await pumpUntil(
        tester,
        () async {
          for (final issue in Walk.issues) {
            if (!await movedOrRaised(issue.id)) return false;
          }
          return true;
        },
        timeout: const Duration(minutes: 5),
        what: 'the planner to move ${Walk.issues.map((issue) => issue.id).join(' and ')} to Reading or past it',
      );
      // The operator's order for this run: a builder that waited for a build of work held at the gate until its time
      // limit, since Porelo hands no verdict for such work, is repaired by hand, by moving its issue on to Review, as
      // a failed reader is, and noted: this planner offers a failed builder no start of its reader, and no start of the
      // story while the run needs attention.
      for (final issue in Walk.issues) {
        if (await probeHolds(['attention', issue.id, 'FAILED'])) {
          noteStep(
            '   HAND: ${issue.id} has FAILED, its builder ended at its time limit waiting for a build; '
            'the person moves it to Review',
          );
          await toTheStory(tester);
          await moveAndSave(tester, issue.id, 'Review');
          await pumpUntil(
            tester,
            () async => !await probeHolds(['attention', issue.id, 'FAILED']),
            timeout: const Duration(minutes: 2),
            what: 'the planner to take ${issue.id} to Review',
          );
        }
      }
      for (final issue in Walk.issues) {
        await probe(['attention', issue.id, 'NONE']);
      }
    });
