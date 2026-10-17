import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/operations.dart';

/// Usage: the record marks it as failed
Future<void> theRecordMarksItAsFailed(WidgetTester tester) async {
  // Words alone are not enough: an operation whose summary happens to mention a failure while it
  // is recorded as a success reads as green in the one place somebody scans.
  expect(find.descendant(of: find.byType(OperationsList), matching: find.byIcon(Icons.error_outline)), findsOneWidget);
}
