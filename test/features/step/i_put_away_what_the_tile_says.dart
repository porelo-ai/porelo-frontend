import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';

/// Usage: I put away what the tile {'porelo-checkout-shell'} says
Future<void> iPutAwayWhatTheTileSays(WidgetTester tester, String work) async {
  await toTheTile(tester, work);
  await tester.tap(find.descendant(of: tileFor(work), matching: find.byKey(const Key('tile-put-away'))));
  await World.settle(tester);
}
