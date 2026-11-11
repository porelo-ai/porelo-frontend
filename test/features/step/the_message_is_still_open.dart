import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the message is still open
Future<void> theMessageIsStillOpen(WidgetTester tester) async {
  expect(find.byKey(const Key('held-message-dialog')), findsOneWidget);
}
