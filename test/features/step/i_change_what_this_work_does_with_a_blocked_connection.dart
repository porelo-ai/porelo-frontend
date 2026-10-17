import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';
import 'i_open_the_command_finder.dart';

/// Usage: I change what this work does with a blocked connection
Future<void> iChangeWhatThisWorkDoesWithABlockedConnection(WidgetTester tester) async {
  await iOpenTheCommandFinder(tester);
  await tester.enterText(find.byType(TextField), 'Change what this work does with a blocked connection');
  await World.settle(tester);
  await tester.tap(find.widgetWithText(ListTile, 'Change what this work does with a blocked connection'));
  await World.settle(tester);
  await followTheFinder(tester);
}
