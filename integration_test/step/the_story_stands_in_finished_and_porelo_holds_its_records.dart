import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';

/// Usage: the story stands in Finished and porelo holds its records
Future<void> theStoryStandsInFinishedAndPoreloHoldsItsRecords(WidgetTester tester) =>
    walked(tester, '10 read: the story stands in Finished and porelo holds its records', () async {
      for (final issue in Walk.issues) {
        await theIssueStandsIn(issue.id, issue.repository, 'Finished');
        await probe(['store-story', Walk.ownUrl, Walk.story!, issue.id, 'Finished']);
      }
      await probe(['story-state', Walk.story!, 'Finished']);
      await probe(['records', Walk.since]);
    });
