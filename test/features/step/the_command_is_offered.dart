import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the command {'Stop following this project'} is offered
Future<void> theCommandIsOffered(WidgetTester tester, String command) async {
  await tester.enterText(find.byKey(const Key('command-query')), command);
  await World.settle(tester);

  final tile = tester.widget<ListTile>(
    find.descendant(of: find.byType(Dialog), matching: find.widgetWithText(ListTile, command)),
  );
  expect(tile.enabled, isTrue, reason: '$command should be runnable now');
}
