import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the review says {'Author'} is {'not reported by the machine'}
Future<void> theReviewSaysIs(WidgetTester tester, String fact, String value) async {
  final row = find.byKey(ValueKey<String>('review-fact $fact'));
  expect(row, findsOneWidget);
  expect(find.descendant(of: row, matching: find.text(fact)), findsOneWidget);
  expect(find.descendant(of: row, matching: find.textContaining(value)), findsWidgets);
}
