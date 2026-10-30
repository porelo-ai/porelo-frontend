import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I pick {'Check whether this machine can run anything'} in the finder
///
/// Picked and not followed, so what the finder did by itself can be looked at.
Future<void> iPickInTheFinder(WidgetTester tester, String command) async {
  await tester.enterText(find.byKey(const Key('command-query')), command);
  await World.settle(tester);
  await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.widgetWithText(ListTile, command)));
  await World.settle(tester);
}
