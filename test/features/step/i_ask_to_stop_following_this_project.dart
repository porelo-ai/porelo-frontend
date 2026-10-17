import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';
import 'i_open_the_command_finder.dart';

/// Usage: I ask to stop following this project
Future<void> iAskToStopFollowingThisProject(WidgetTester tester) async {
  await iOpenTheCommandFinder(tester);
  await tester.enterText(find.byType(TextField), 'Stop following this project');
  await World.settle(tester);
  await tester.tap(find.widgetWithText(ListTile, 'Stop following this project'));
  await World.settle(tester);
  await followTheFinder(tester);
}
