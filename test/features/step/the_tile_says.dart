import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the tile {'porelo-checkout-shell'} says {'blocked for'}
///
/// Under *Needs you*, what its rows there say; elsewhere, its tile.
Future<void> theTileSays(WidgetTester tester, String work, String words) async {
  final tile = await whereTheTileIs(tester, work);
  expect(tile, findsWidgets, reason: 'nothing is shown for $work');
  expect(find.descendant(of: tile, matching: find.textContaining(words)), findsWidgets);
}
