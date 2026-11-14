import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: the other planning provider supplies the board
Future<void> theOtherPlanningProviderSuppliesTheBoard(WidgetTester tester) async {
  await revealPlanning(tester, find.text('Story supplied by another machine'));
  expect(find.text('Story supplied by another machine'), findsOneWidget);
  expect(tester.widget<Text>(find.byKey(const Key('rail-planning-count'))).data, '5');
  expect(find.textContaining('Planning store cannot be read'), findsOneWidget);
}
