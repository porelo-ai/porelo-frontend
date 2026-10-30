import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';
import 'i_open_the_command_finder.dart';

/// Usage: I show what this machine can authenticate against
Future<void> iShowWhatThisMachineCanAuthenticateAgainst(WidgetTester tester) async {
  await iOpenTheCommandFinder(tester);
  await tester.enterText(find.byKey(const Key('command-query')), 'Show what this machine can authenticate against');
  await World.settle(tester);
  await tester.tap(find.widgetWithText(ListTile, 'Show what this machine can authenticate against'));
  await World.settle(tester);
  await followTheFinder(tester);
}
