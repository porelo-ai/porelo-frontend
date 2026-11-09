import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the machine reports issues in Reading and Reworking
Future<void> theMachineReportsIssuesInReadingAndReworking(WidgetTester tester) async {
  final board = planningFixture();
  final story = planningMaps(board, 'stories').singleWhere((story) => story['id'] == 'ST291');
  final issues = (story['issues'] as List<dynamic>).cast<Map<String, dynamic>>();
  issues[0].addAll({'state': 'Reading', 'rounds': 2, 'roundsMost': 5});
  issues[1].addAll({'state': 'Reworking', 'rounds': 4, 'roundsMost': 7});
  await pushPlanning(tester, board);
}
