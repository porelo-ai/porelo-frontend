import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the machine moves a planning story
Future<void> theMachineMovesAPlanningStory(WidgetTester tester) async {
  final board = planningFixture();
  // An open story follows its issues: the machine moves them, and the story stands where they all wait.
  final story = planningMaps(board, 'stories').singleWhere((story) => story['id'] == 'ST291');
  for (final issue in planningMaps(story, 'issues')) {
    issue['state'] = 'Review';
  }
  story['state'] = 'Review';
  board['revision'] = 'changed-2';
  await pushPlanning(tester, board);
}
