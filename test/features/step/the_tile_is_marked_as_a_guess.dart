import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the tile {'porelo-checkout-shell'} is marked as a guess
Future<void> theTileIsMarkedAsAGuess(WidgetTester tester, String work) async {
  await toTheTile(tester, work);
  expect(
    find.descendant(of: tileFor(work), matching: find.byKey(const Key('tile-inferred'))),
    findsOneWidget,
  );
}
