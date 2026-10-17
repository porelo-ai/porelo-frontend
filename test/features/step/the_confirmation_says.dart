import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the confirmation says {'exists nowhere else'}
Future<void> theConfirmationSays(WidgetTester tester, String words) async {
  expect(find.descendant(of: find.byType(AlertDialog), matching: find.textContaining(words)), findsOneWidget);
}
