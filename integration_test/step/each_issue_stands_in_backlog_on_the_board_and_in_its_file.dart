import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';

/// Usage: each issue stands in Backlog on the board and in its file
Future<void> eachIssueStandsInBacklogOnTheBoardAndInItsFile(WidgetTester tester) =>
    walked(tester, '4 read: each issue stands in Backlog', () async {
      for (final issue in Walk.issues) {
        await theIssueStandsIn(issue.id, issue.repository, 'Backlog');
      }
      await probe(['story-state', Walk.story!, 'Backlog']);
    });
