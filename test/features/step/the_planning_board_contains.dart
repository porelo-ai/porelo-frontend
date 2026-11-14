import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';
import '../support/planning_details.dart';

/// Usage: the planning board contains {words}
Future<void> thePlanningBoardContains(WidgetTester tester, String words) async {
  final board = planningElement('board');
  expect(board, findsOneWidget);
  // Each phase builds only the cards in its view: the words are looked for through the phases first.
  await revealPlanning(
    tester,
    find.descendant(
      of: board,
      matching: find.byWidgetPredicate((widget) => widget is Text && (widget.data?.contains(words) ?? false)),
    ),
  );
  expect(planningText(tester, board), contains(words));
}
