import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';

/// Usage: the proposal moved nothing
Future<void> theProposalMovedNothing(WidgetTester tester) =>
    walked(tester, '5 read: the proposal moved nothing', () async {
      // The form orders and starts with one press, so the planner's run is read as started in the next step.
      for (final issue in Walk.issues) {
        await probe(['issue-state', issue.id, 'Backlog']);
      }
      await probe(['story-state', Walk.story!, 'Backlog']);
    });
