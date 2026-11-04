import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';

/// Usage: I go from the row to the console of {'porelo-billing-shell'}
Future<void> iGoFromTheRowToTheConsoleOf(WidgetTester tester, String work) async {
  await toTheTile(tester, work);
  final inTheRow = find.descendant(
    of: tileFor(work),
    matching: find.byWidgetPredicate(
      (widget) => widget.key == const Key('tile-follow') || widget.key == const Key('tile-attach'),
    ),
  );
  await tester.ensureVisible(inTheRow);
  await tester.pump();
  await tester.tap(inTheRow);
  await World.settle(tester);
}
