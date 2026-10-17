import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';
import 'i_open_the_command_finder.dart';

/// Usage: I ask the upstream how far behind this project is
Future<void> iAskTheUpstreamHowFarBehindThisProjectIs(WidgetTester tester) async {
  await iOpenTheCommandFinder(tester);
  await tester.enterText(find.byType(TextField), 'Ask the upstream how far behind this project is');
  await World.settle(tester);
  await tester.tap(inTheFinder('Ask the upstream how far behind this project is'));
  await World.settle(tester);
  await followTheFinder(tester);
}
