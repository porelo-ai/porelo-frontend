import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the planning state is renamed on the machine
Future<void> thePlanningStateIsRenamedOnTheMachine(WidgetTester tester) async {
  final board = planningFixture();
  for (final state in planningMaps(board, 'states')) {
    if (state['name'] == 'In analysis') state['name'] = 'Investigating';
  }
  for (final phase in planningMaps(board, 'phases')) {
    phase['states'] = (phase['states'] as List<dynamic>)
        .map((name) => name == 'In analysis' ? 'Investigating' : name)
        .toList();
  }
  for (final story in planningMaps(board, 'stories')) {
    if (story['state'] == 'In analysis') story['state'] = 'Investigating';
  }
  await pushPlanning(tester, board);
}
