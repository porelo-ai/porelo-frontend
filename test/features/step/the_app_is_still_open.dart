import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the app is still open
Future<void> theAppIsStillOpen(WidgetTester tester) async {
  // Declining leaves everything exactly as it was; nothing here closes or restarts on its own.
  expect(find.byKey(const Key('shell-rail')), findsOneWidget);
}
