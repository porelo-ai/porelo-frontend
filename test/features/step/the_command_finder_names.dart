import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the command finder names {'Refresh from the backend'}
Future<void> theCommandFinderNames(WidgetTester tester, String command) async {
  // Typed for rather than scrolled to: the finder lists every action in the product, so the list
  // is long by design and gets longer with every requirement. Typing is what it is for.
  await tester.enterText(find.byKey(const Key('command-query')), command);
  await World.settle(tester);
  expect(find.descendant(of: find.byType(Dialog), matching: find.widgetWithText(ListTile, command)), findsOneWidget);
}
