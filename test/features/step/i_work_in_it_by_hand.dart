import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';
import 'i_open_the_command_finder.dart';

/// Usage: I work in it by hand
Future<void> iWorkInItByHand(WidgetTester tester) async {
  await iOpenTheCommandFinder(tester);
  await tester.enterText(find.byKey(const Key('command-query')), 'Work in it by hand');
  await World.settle(tester);
  await tester.tap(inTheFinder('Work in it by hand'));
  await World.settle(tester);
  await followTheFinder(tester);
}
