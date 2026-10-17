import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';
import 'i_open_the_command_finder.dart';

/// Usage: I ask to stop Porelo on this machine
Future<void> iAskToStopPoreloOnThisMachine(WidgetTester tester) async {
  await iOpenTheCommandFinder(tester);
  await tester.enterText(find.byType(TextField), 'Stop Porelo on this machine');
  await World.settle(tester);
  await tester.tap(inTheFinder('Stop Porelo on this machine'));
  await World.settle(tester);
  await followTheFinder(tester);
}
