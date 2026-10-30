import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the command finder does not name {'Run nightly-tests in checkout'}
Future<void> theCommandFinderDoesNotName(WidgetTester tester, String command) async {
  await tester.enterText(find.byKey(const Key('command-query')), command);
  await World.settle(tester);
  expect(find.descendant(of: find.byType(Dialog), matching: find.widgetWithText(ListTile, command)), findsNothing);
}
