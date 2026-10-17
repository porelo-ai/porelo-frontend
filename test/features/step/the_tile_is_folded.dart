import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the tile {'porelo-billing-shell'} is folded {true}
///
/// Folded, a tile says its work, its machine and its mark, and not how it stands in words.
Future<void> theTileIsFolded(WidgetTester tester, String work, bool folded) async {
  expect(tileFor(work), findsOneWidget);
  expect(
    find.descendant(of: tileFor(work), matching: find.byKey(const Key('tile-headline'))).evaluate().isEmpty,
    folded,
  );
  expect(find.descendant(of: tileFor(work), matching: find.byKey(const Key('tile-machine'))), findsOneWidget);
}
