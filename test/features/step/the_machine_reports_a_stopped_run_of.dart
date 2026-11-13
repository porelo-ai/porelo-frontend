import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the machine reports a stopped run of {story}
Future<void> theMachineReportsAStoppedRunOf(WidgetTester tester, String story) async {
  final board = planningFixture();
  final reported = planningMaps(board, 'stories').singleWhere((each) => each['id'] == story);
  final issue = (reported['issues'] as List<dynamic>).first as Map<String, dynamic>;
  issue['needsYou'] = true;
  reported['work'] = <String, dynamic>{
    'run': '00000000-0000-4000-9000-0000000000aa',
    'atWork': false,
    'tasks': <Map<String, dynamic>>[],
    'issues': [
      {'issue': issue['id'], 'reason': 'STOPPED', 'needsYou': true, 'rounds': 0, 'roundsMost': 2},
    ],
  };
  await pushPlanning(tester, board);
}
