import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';

/// Usage: the idea a task brought back is an issue in Idea
Future<void> theIdeaATaskBroughtBackIsAnIssueInIdea(WidgetTester tester) =>
    walked(tester, '10 [ideas] the idea a task brought back is an issue in Idea', () async {
      // An issue of the run in Idea that is none of the story's own: what a task brought back, as the planner's API
      // answers it.
      final own = {for (final issue in Walk.issues) issue.id};
      final found = [
        for (final id in (await probe(['issues-in', 'Idea'])).split('\n').map((each) => each.trim()))
          if (id.isNotEmpty && !own.contains(id)) id,
      ];
      if (found.isEmpty) {
        fail('asked the planner for an issue in Idea beside the story\'s ${own.join(', ')}; none');
      }
      for (final id in found) {
        await probe(['issue-state', id, 'Idea']);
      }
      noteStep('   brought back: ${found.join(', ')}');
    });
