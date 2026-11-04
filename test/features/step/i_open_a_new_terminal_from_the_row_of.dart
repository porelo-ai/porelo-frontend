import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';

/// Usage: I open a new terminal from the row of {'porelo-billing-shell'}
Future<void> iOpenANewTerminalFromTheRowOf(WidgetTester tester, String work) async {
  final step = find.descendant(of: tileFor(work), matching: find.byKey(const Key('tile-new-terminal')));
  await tester.ensureVisible(step);
  await tester.pump();
  await tester.tap(step);
  await World.settle(tester);
}
