import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the tile {'porelo-checkout-shell'} says {'blocked for'}
Future<void> theTileSays(WidgetTester tester, String work, String words) async {
  await toTheTile(tester, work);
  expect(tileFor(work), findsOneWidget, reason: 'no tile for $work');
  expect(find.descendant(of: tileFor(work), matching: find.textContaining(words)), findsWidgets);
}
