import 'package:flutter_test/flutter_test.dart';

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
        await probe(['store-story', Walk.ownUrl, story, issue.id, 'Idea']);
        await probe(['store-issue', Walk.urlOf(issue.repository), issue.id, 'Idea']);
      }
      await probe(['events', '20']);
    });
