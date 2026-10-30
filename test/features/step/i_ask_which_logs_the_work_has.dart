import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';
import 'i_open_the_command_finder.dart';

/// Usage: I ask which logs the work has
Future<void> iAskWhichLogsTheWorkHas(WidgetTester tester) async {
  await iOpenTheCommandFinder(tester);
  await tester.enterText(find.byKey(const Key('command-query')), 'Read one of its logs');
  await World.settle(tester);
  await tester.tap(inTheFinder('Read one of its logs'));
  await World.settle(tester);
  await followTheFinder(tester);
}
