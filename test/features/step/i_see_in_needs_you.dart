import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';

/// Usage: I see {'porelo-checkout-shell'} in Needs you
Future<void> iSeeInNeedsYou(WidgetTester tester, String work) async {
  await toTheTile(tester, work);
  final step = find.descendant(of: tileFor(work), matching: find.byKey(const Key('tile-see-needs')));
  await tester.ensureVisible(step);
  await tester.pump();
  await tester.tap(step);
  await World.settle(tester);
}
