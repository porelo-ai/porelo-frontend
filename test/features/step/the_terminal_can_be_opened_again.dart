import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the terminal can be opened again
Future<void> theTerminalCanBeOpenedAgain(WidgetTester tester) async {
  expect(find.text('Open it again'), findsOneWidget);
  expect(tester.widget<OutlinedButton>(find.byKey(const Key('open-vault-terminal'))).onPressed, isNotNull);
}
