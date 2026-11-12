import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/idea_walk.dart';

/// Usage: the window posts the end of the builder task
Future<void> theWindowPostsTheEndOfTheBuilderTask(WidgetTester tester) =>
    walked(tester, '8 the window posts the end of the builder task', () async {
      // The window posts ENDED by itself once porelo lists the end; the planner's move to Reading is its effect.
      Future<bool> movedOrRaised(String issue) async =>
          await probeHolds(['issue-state', issue, 'Reading']) || !await probeHolds(['attention', issue, 'NONE']);
      await pumpUntil(
        tester,
        () async {
          for (final issue in Walk.issues) {
            if (!await movedOrRaised(issue.id)) return false;
          }
          return true;
        },
        timeout: const Duration(minutes: 5),
        what: 'the planner to move ${Walk.issues.map((issue) => issue.id).join(' and ')} to Reading',
      );
      for (final issue in Walk.issues) {
        await probe(['attention', issue.id, 'NONE']);
      }
    });
