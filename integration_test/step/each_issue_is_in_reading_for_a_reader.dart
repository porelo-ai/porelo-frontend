import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';

/// Usage: each issue is in Reading for a reader
Future<void> eachIssueIsInReadingForAReader(WidgetTester tester) =>
    walked(tester, '8 read: each issue is in Reading', () async {
      for (final issue in Walk.issues) {
        // A reader the window started at once may have read the issue already and moved it on to Review.
        final read = await probeHolds(['issue-state', issue.id, 'Review']);
        await theIssueStandsIn(issue.id, issue.repository, read ? 'Review' : 'Reading');
        if (read) noteStep('   ${issue.id} was read already and stands in Review');
      }
    });
