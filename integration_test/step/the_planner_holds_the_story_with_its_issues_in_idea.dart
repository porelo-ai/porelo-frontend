import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/idea_walk.dart';

/// Usage: the planner holds the story with its issues in Idea
Future<void> thePlannerHoldsTheStoryWithItsIssuesInIdea(WidgetTester tester) =>
    walked(tester, '3 read: the planner holds the story with its issues in Idea', () async {
      final story = Walk.story = (await probe(['story-id', Walk.title])).trim();
      await probe(['story-state', story, 'Idea']);
      final issues = Walk.issues = await theStorysIssues(story);
      expect(issues, isNotEmpty, reason: '$story has issues');
      for (final issue in issues) {
        expect(issue.state, 'Idea', reason: '${issue.id} stands in Idea');
        // The planner answers before its push has reached the forge.
        await pumpUntil(
          tester,
          () => probeHolds(['store-story', Walk.ownUrl, story, issue.id, 'Idea']),
          timeout: const Duration(minutes: 2),
          what: 'the forge to hold the story file of $story',
        );
        await probe(['store-story', Walk.ownUrl, story, issue.id, 'Idea']);
        await inTheForge(['store-issue', Walk.urlOf(issue.repository), issue.id, 'Idea']);
      }
      await probe(['events', '20']);
      // Its idea saved, the window removed the ended discussion: porelo on the machine lists it no longer.
      await pumpUntil(
        tester,
        () => isGone(Walk.discussion!),
        timeout: const Duration(minutes: 1),
        what: 'porelo to list ${Walk.discussion} no longer',
      );
    });
