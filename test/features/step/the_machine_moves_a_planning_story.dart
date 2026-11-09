import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the machine moves a planning story
Future<void> theMachineMovesAPlanningStory(WidgetTester tester) async {
  final board = planningFixture();
  planningMaps(board, 'stories').singleWhere((story) => story['id'] == 'ST291')['state'] = 'Review';
  board['revision'] = 'changed-2';
  await pushPlanning(tester, board);
}
