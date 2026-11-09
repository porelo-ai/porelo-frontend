import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the planning board contains {words}
Future<void> thePlanningBoardContains(WidgetTester tester, String words) async {
  final board = planningElement('board');
  expect(board, findsOneWidget);
  expect(planningText(tester, board), contains(words));
}
