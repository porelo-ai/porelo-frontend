import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'i_open_the_command_finder.dart';

import '../support/tiles.dart';
import '../support/world.dart';

/// Usage: I choose the command {'Refresh from the backend'}
Future<void> iChooseTheCommand(WidgetTester tester, String command) async {
  await iOpenTheCommandFinder(tester);
  // Typing first is how a finder is used, and it keeps the wanted entry on screen whatever the
  // list grows to.
  await tester.enterText(find.byKey(const Key('command-query')), command);
  await World.settle(tester);
  await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.widgetWithText(ListTile, command)));
  await World.settle(tester);
  // The finder goes to where the action lives and marks it there; that is where it is pressed.
  await followTheFinder(tester);
}
