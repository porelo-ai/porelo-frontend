import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the folded planning build retains its count and marks
Future<void> theFoldedPlanningBuildRetainsItsCountAndMarks(WidgetTester tester) async {
  final phase = planningElement('phase Build');
  expect(find.descendant(of: phase, matching: find.text('10')), findsOneWidget);
  expect(find.descendant(of: phase, matching: find.text('▲▲')), findsNWidgets(7));
  expect(find.descendant(of: phase, matching: find.text('▼')), findsNWidgets(3));
  expect(find.descendant(of: phase, matching: find.byType(Card)), findsNothing);
}
