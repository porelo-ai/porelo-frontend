import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the other planning provider supplies the board
Future<void> theOtherPlanningProviderSuppliesTheBoard(WidgetTester tester) async {
  expect(find.text('Story supplied by another machine'), findsOneWidget);
  expect(tester.widget<Text>(find.byKey(const Key('rail-planning-count'))).data, '7');
  expect(find.textContaining('Planning store cannot be read'), findsOneWidget);
}
