import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/idea_walk.dart';

/// Usage: the window posts the end of the builder task
Future<void> theWindowPostsTheEndOfTheBuilderTask(WidgetTester tester) =>
    walked(tester, '8 the window posts the end of the builder task', () async {
      // The window posts ENDED by itself once porelo lists the end; the planner's move to Reading is its effect.
      final issue = Walk.issues.first.id;
      await pumpUntil(
        tester,
        () async =>
            await probeHolds(['issue-state', issue, 'Reading']) || !await probeHolds(['attention', issue, 'NONE']),
        timeout: const Duration(minutes: 5),
        what: 'the planner to move $issue to Reading',
      );
      await probe(['attention', issue, 'NONE']);
    });
