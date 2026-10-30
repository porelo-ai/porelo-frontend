import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';
import 'i_open_the_command_finder.dart';

/// Usage: I show what has been backed up here
Future<void> iShowWhatHasBeenBackedUpHere(WidgetTester tester) async {
  await iOpenTheCommandFinder(tester);
  await tester.enterText(find.byKey(const Key('command-query')), 'Show what has been backed up here');
  await World.settle(tester);
  await tester.tap(inTheFinder('Show what has been backed up here'));
  await World.settle(tester);
  await followTheFinder(tester);
}
