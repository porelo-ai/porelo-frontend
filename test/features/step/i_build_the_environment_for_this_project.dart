import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';
import 'i_open_the_command_finder.dart';

/// Usage: I build the environment for this project
Future<void> iBuildTheEnvironmentForThisProject(WidgetTester tester) async {
  await iOpenTheCommandFinder(tester);
  await tester.enterText(find.byType(TextField), 'Build the environment for this project');
  await World.settle(tester);
  await tester.tap(inTheFinder('Build the environment for this project'));
  await World.settle(tester);
  await followTheFinder(tester);
}
