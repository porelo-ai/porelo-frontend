import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the tile of {'porelo-checkout-shell'} ends with {'Finished'}
Future<void> theTileOfEndsWith(WidgetTester tester, String work, String line) async {
  await toTheTile(tester, work);
  expect(endedLine(work, line), findsOneWidget);
}

/// Finds [line] in the last line of [work]'s tile, which says what an unattended run came to.
Finder endedLine(String work, String line) => find.descendant(
  of: find.descendant(of: tileFor(work), matching: find.byKey(const Key('tile-run-ended'))),
  matching: find.textContaining(line),
  matchRoot: true,
);
