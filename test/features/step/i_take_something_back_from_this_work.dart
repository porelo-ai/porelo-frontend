import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';
import 'i_open_the_command_finder.dart';

/// Usage: I take something back from this work
Future<void> iTakeSomethingBackFromThisWork(WidgetTester tester) async {
  await iOpenTheCommandFinder(tester);
  await tester.enterText(find.byKey(const Key('command-query')), 'Take something back from this work');
  await World.settle(tester);
  await tester.tap(inTheFinder('Take something back from this work'));
  await World.settle(tester);
  await followTheFinder(tester);
}
