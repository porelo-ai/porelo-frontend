import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the fact {'tokens'} of {'porelo-billing-shell'} says {'184 k'}
Future<void> theFactOfSays(WidgetTester tester, String fact, String work, String says) async {
  final found = find.descendant(of: tileFor(work), matching: find.byKey(ValueKey<String>('tile-fact $fact')));
  expect(tester.widget<Text>(found).data, says);
}
