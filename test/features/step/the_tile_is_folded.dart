import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the tile {'porelo-billing-shell'} is folded {true}
///
/// Folded, a row says its work, where it runs and its state, and nothing more.
Future<void> theTileIsFolded(WidgetTester tester, String work, bool folded) async {
  expect(tileFor(work), findsOneWidget);
  expect(
    find.descendant(of: tileFor(work), matching: find.byKey(const Key('tile-details'))).evaluate().isEmpty,
    folded,
  );
  expect(find.descendant(of: tileFor(work), matching: find.byKey(const Key('tile-machine'))), findsOneWidget);
}
