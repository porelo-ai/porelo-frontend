import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the forge form takes no token
Future<void> theForgeFormTakesNoToken(WidgetTester tester) async {
  // Harm: a token field exposes a secret through widget state and diagnostics.
  expect(find.byKey(const Key('forge-token')), findsNothing);
  expect(tester.widgetList<TextField>(find.byType(TextField)).where((each) => each.obscureText), isEmpty);
}
