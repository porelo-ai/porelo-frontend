import 'package:flutter_test/flutter_test.dart';

import 'the_tile_of_shows.dart';

/// Usage: the tile of {'porelo-billing-shell'} does not show {'reading the contracts'} yet
Future<void> theTileOfDoesNotShowYet(WidgetTester tester, String work, String line) async {
  expect(consoleSaying(work, line), findsNothing);
}
