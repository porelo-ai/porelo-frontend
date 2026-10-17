import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';

/// Usage: I work in {'porelo-checkout-shell'} by hand from its tile
Future<void> iWorkInByHandFromItsTile(WidgetTester tester, String work) async {
  await toTheTile(tester, work);
  final attach = find.descendant(of: tileFor(work), matching: find.byKey(const Key('tile-attach')));
  await tester.ensureVisible(attach);
  await tester.pump();
  await tester.tap(attach);
  await World.settle(tester);
}
