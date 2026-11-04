import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the tile of {'porelo-billing-shell'} draws no console
Future<void> theTileOfDrawsNoConsole(WidgetTester tester, String work) async {
  expect(find.byKey(ValueKey<String>('tile-console $work')), findsNothing);
}
