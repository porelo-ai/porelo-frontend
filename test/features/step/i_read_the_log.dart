import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';
import 'i_open_the_command_finder.dart';

/// Usage: I read the log {'agent.log'}
Future<void> iReadTheLog(WidgetTester tester, String log) async {
  await iOpenTheCommandFinder(tester);
  await tester.enterText(find.byKey(const Key('command-query')), 'Read one of its logs');
  await World.settle(tester);
  await tester.tap(inTheFinder('Read one of its logs'));
  await World.settle(tester);
  await followTheFinder(tester);

  // Chosen from what the daemon says the task has, never typed: which files exist depends on
  // what the task started, and only that end knows.
  await tester.tap(inTheFinder(log));
  await World.settle(tester);
}
