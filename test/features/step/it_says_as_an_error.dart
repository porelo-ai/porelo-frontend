import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: it says as an error {words}
Future<void> itSaysAsAnError(WidgetTester tester, String words) async {
  final outcome = find.byKey(const Key('held-message-outcome'));
  expect(outcome, findsOneWidget);
  final said = tester.widget<Text>(outcome);
  expect(said.data, words);
  expect(said.style?.color, Theme.of(tester.element(outcome)).colorScheme.error);
}
