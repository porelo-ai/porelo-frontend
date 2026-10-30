import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the command finder is open
Future<void> theCommandFinderIsOpen(WidgetTester tester) async {
  // Without the keyboard landing in the view, the shortcut reaches nothing and nothing opens.
  expect(find.byKey(const Key('command-query')), findsOneWidget);
}
