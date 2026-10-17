import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the tile {'porelo-billing-shell'} is not marked as a guess
Future<void> theTileIsNotMarkedAsAGuess(WidgetTester tester, String work) async {
  await toTheTile(tester, work);
  expect(tileFor(work), findsOneWidget, reason: 'no tile for $work');
  expect(
    find.descendant(of: tileFor(work), matching: find.byKey(const Key('tile-inferred'))),
    findsNothing,
  );
}
