import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the machine reports a stopped reading
Future<void> theMachineReportsAStoppedReading(WidgetTester tester) async {
  final board = planningFixture();
  final story = planningMaps(board, 'stories').singleWhere((story) => story['id'] == 'ST291');
  final issue = (story['issues'] as List<dynamic>).first as Map<String, dynamic>;
  issue.addAll({'state': 'Reading', 'rounds': 3, 'roundsMost': 4, 'readingStopped': true});
  await pushPlanning(tester, board);
}
