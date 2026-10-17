import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the operation is still running
Future<void> theOperationIsStillRunning(WidgetTester tester) async {
  // Read off the status line rather than the model: what matters is that a person can see it is
  // still going without having to be looking at it.
  final indicator = tester.widget<Text>(
    find.descendant(of: find.byKey(const Key('operations-indicator')), matching: find.byType(Text)),
  );
  expect(indicator.data, contains('running'));
}
