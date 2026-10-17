import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the tile {'porelo-checkout-shell'} shows the state {'stopped'}
Future<void> theTileShowsTheState(WidgetTester tester, String work, String state) async {
  await toTheTile(tester, work);
  expect(
    find.descendant(of: tileFor(work), matching: find.byKey(ValueKey<String>('tile-state $state'))),
    findsOneWidget,
  );
}
