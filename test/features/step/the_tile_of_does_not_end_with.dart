import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import 'the_tile_of_ends_with.dart';

/// Usage: the tile of {'porelo-checkout-shell'} does not end with {'reviewed'}
Future<void> theTileOfDoesNotEndWith(WidgetTester tester, String work, String line) async {
  await toTheTile(tester, work);
  expect(endedLine(work, line), findsNothing);
}
