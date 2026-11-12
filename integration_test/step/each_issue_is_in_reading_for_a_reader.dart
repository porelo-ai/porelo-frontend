import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';

/// Usage: each issue is in Reading for a reader
Future<void> eachIssueIsInReadingForAReader(WidgetTester tester) =>
    walked(tester, '8 read: each issue is in Reading', () async {
      for (final issue in Walk.issues) {
        await theIssueStandsIn(issue.id, issue.repository, 'Reading');
      }
    });
