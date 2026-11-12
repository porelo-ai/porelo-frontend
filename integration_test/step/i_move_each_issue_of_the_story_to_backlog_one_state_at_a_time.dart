import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';

/// Usage: I move each issue of the story to Backlog one state at a time
Future<void> iMoveEachIssueOfTheStoryToBacklogOneStateAtATime(WidgetTester tester) =>
    walked(tester, '4 the person moves each issue to Backlog, one state at a time', () async {
      await toTheStory(tester);
      // The states a person may move to, in the board's order: every one between Idea and Backlog is walked.
      final offered = await theMovesOffered(tester, Walk.issues.first.id);
      final from = offered.indexOf('Idea'), to = offered.indexOf('Backlog');
      if (from < 0 || to <= from) fail('the move menu offers no way from Idea to Backlog: $offered');
      for (final state in offered.sublist(from + 1, to + 1)) {
        for (final issue in Walk.issues) {
          // A run taken up again finds an issue the window already moved on.
          if (await probeHolds(['issue-state', issue.id, state])) continue;
          await moveAndSave(tester, issue.id, state);
          await theIssueStandsIn(issue.id, issue.repository, state);
          noteStep('   ${issue.id} moved to $state and read there');
        }
        await probe(['story-state', Walk.story!, state]);
      }
    });
