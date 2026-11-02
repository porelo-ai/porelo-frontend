import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';
import 'i_open_the_command_finder.dart';

/// Usage: I ask to remove this project
Future<void> iAskToRemoveThisProject(WidgetTester tester) async {
  await iOpenTheCommandFinder(tester);
  await tester.enterText(find.byKey(const Key('command-query')), 'Remove this project');
  await World.settle(tester);
  await tester.tap(find.widgetWithText(ListTile, 'Remove this project'));
  await World.settle(tester);
  await followTheFinder(tester);
}
