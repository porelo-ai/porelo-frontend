import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';

/// Usage: I review the work {'porelo-checkout-migrate'} from its tile
Future<void> iReviewTheWorkFromItsTile(WidgetTester tester, String work) async {
  await toTheTile(tester, work);
  await tester.tap(find.descendant(of: tileFor(work), matching: find.byKey(const Key('tile-review'))));
  await World.settle(tester);
}
