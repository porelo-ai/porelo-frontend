import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';

/// Usage: I open the menu of the tile {'porelo-checkout-shell'}
Future<void> iOpenTheMenuOfTheTile(WidgetTester tester, String work) async {
  await toTheTile(tester, work);
  await tester.tap(find.descendant(of: tileFor(work), matching: find.byWidgetPredicate((each) => each.key is ValueKey<String> && (each.key! as ValueKey<String>).value.startsWith('tile-menu'))));
  await World.settle(tester);
}
