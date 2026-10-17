import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the question is asked in its own dialog
///
/// **Not at the end of the panel.** It was, and an offer below the fold of a scrolling dialog is
/// an offer nobody sees: the question was found only by scrolling for it.
Future<void> theQuestionIsAskedInItsOwnDialog(WidgetTester tester) async {
  final asking = find.ancestor(of: find.byKey(const Key('offer-to-start')), matching: find.byType(AlertDialog));
  expect(asking, findsOneWidget);
  expect(
    find.descendant(of: asking, matching: find.byKey(const Key('machine-name'))),
    findsNothing,
    reason: 'the question is inside the panel that adds a machine, not in front of it',
  );
}
