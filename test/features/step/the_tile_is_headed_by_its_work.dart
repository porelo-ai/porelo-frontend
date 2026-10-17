import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the tile {'porelo-checkout-shell'} is headed by its work
Future<void> theTileIsHeadedByItsWork(WidgetTester tester, String work) async {
  await toTheTile(tester, work);
  final heading = tester.widget<SelectableText>(
    find.descendant(of: tileFor(work), matching: find.byKey(const Key('tile-what'))),
  );
  expect(heading.style?.fontWeight, FontWeight.bold);
  // Above the machine, which is the same on every tile of a machine's page.
  final above = tester.getTopLeft(find.descendant(of: tileFor(work), matching: find.byKey(const Key('tile-what')))).dy;
  final machine = tester
      .getTopLeft(find.descendant(of: tileFor(work), matching: find.byKey(const Key('tile-machine'))))
      .dy;
  expect(above, lessThan(machine));
}
