import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';

/// Usage: each issue stands in Backlog on the board
Future<void> eachIssueStandsInBacklogOnTheBoard(WidgetTester tester) =>
    walked(tester, '4 read: each issue stands in Backlog', () async {
      for (final issue in Walk.issues) {
        await theIssueStandsIn(issue.id, 'Backlog');
      }
      await probe(['story-state', Walk.story!, 'Backlog']);
    });
