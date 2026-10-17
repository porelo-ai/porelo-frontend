import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the tile of {'porelo-billing-shell'} shows {'reading the contracts'}
Future<void> theTileOfShows(WidgetTester tester, String work, String line) async {
  await toTheTile(tester, work);
  expect(consoleSaying(work, line), findsOneWidget);
}

/// Finds [line] in the console of [work]'s tile.
Finder consoleSaying(String work, String line) => find.descendant(
  of: find.byKey(ValueKey<String>('tile-console $work')),
  matching: find.textContaining(line, findRichText: true),
);
