import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';
import 'i_open_the_command_finder.dart';

/// Usage: I check whether this machine can run anything
Future<void> iCheckWhetherThisMachineCanRunAnything(WidgetTester tester) async {
  await iOpenTheCommandFinder(tester);
  await tester.enterText(find.byType(TextField), 'Check whether this machine can run anything');
  await World.settle(tester);
  await tester.tap(find.widgetWithText(ListTile, 'Check whether this machine can run anything'));
  await World.settle(tester);
  await followTheFinder(tester);
}
