import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';
import 'i_open_the_command_finder.dart';

/// Usage: I stop the selected work
Future<void> iStopTheSelectedWork(WidgetTester tester) async {
  await iOpenTheCommandFinder(tester);
  await tester.enterText(find.byKey(const Key('command-query')), 'Stop it, keeping its workspace');
  await World.settle(tester);
  await tester.tap(inTheFinder('Stop it, keeping its workspace'));
  await World.settle(tester);
  await followTheFinder(tester);
}
