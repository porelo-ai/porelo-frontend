import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';

/// Usage: the story stands in Finished and porelo holds its records
Future<void> theStoryStandsInFinishedAndPoreloHoldsItsRecords(WidgetTester tester) =>
    walked(tester, '10 read: the story stands in Finished and porelo holds its records', () async {
      for (final issue in Walk.issues) {
        await theIssueStandsIn(issue.id, 'Finished');
      }
      // The story lists each of its issues in Finished, as the planner's API answers it.
      final listed = await theStorysIssues(Walk.story!);
      for (final issue in Walk.issues) {
        if (!listed.any((each) => each.id == issue.id && each.state == 'Finished')) {
          fail('asked the planner for ${Walk.story} with ${issue.id} in Finished; it lists $listed');
        }
      }
      await probe(['story-state', Walk.story!, 'Finished']);
      await probe(['records', Walk.since]);
    });
